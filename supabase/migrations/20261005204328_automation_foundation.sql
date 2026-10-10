-- Transactional outbox. No recipient, message body, patient name or provider credentials.
create table private.automation_tasks (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, appointment_id uuid not null,
 appointment_version integer not null, kind text not null check(kind in('google_sync','whatsapp_reminder')),
 status text not null default 'pending' check(status in('pending','processing','retry','blocked','completed','cancelled','failed')),
 due_at timestamptz not null, available_at timestamptz not null, expires_at timestamptz,
 attempts integer not null default 0 check(attempts between 0 and 5), revision integer not null default 1 check(revision>0),
 reason text check(reason in('integration_not_configured','superseded','expired','access_revoked','transient_failure','permanent_failure','lease_expired','result_unknown','retry_policy_pending','attempts_exhausted')),
 lease_token uuid, lease_until timestamptz, created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 unique(clinic_id,id), unique(clinic_id,appointment_id,appointment_version,kind),
 foreign key(clinic_id,appointment_id,appointment_version) references app.appointment_history(clinic_id,appointment_id,version) on delete restrict,
 check(isfinite(due_at) and isfinite(available_at) and (expires_at is null or (isfinite(expires_at) and expires_at>due_at))),
 check((status='processing')=(lease_token is not null and lease_until is not null)),
 check((lease_token is null)=(lease_until is null))
);
create index automation_due_idx on private.automation_tasks(available_at,id) where status in('pending','retry','processing');
create index automation_clinic_idx on private.automation_tasks(clinic_id,created_at desc,id);
create table private.automation_attempts (
 task_id uuid not null references private.automation_tasks(id), number integer not null,
 token uuid not null unique, started_at timestamptz not null default now(), finished_at timestamptz,
 outcome text check(outcome in('blocked','retry','failed','cancelled','lease_expired','result_unknown')),
 primary key(task_id,number), check((finished_at is null)=(outcome is null))
);
create table private.automation_worker_state (
 name text primary key check(name='foundation'), last_run_at timestamptz not null, processed integer not null check(processed>=0)
);
alter table private.automation_tasks enable row level security;
alter table private.automation_attempts enable row level security;
alter table private.automation_worker_state enable row level security;
create policy automation_tasks_private on private.automation_tasks for all using(false) with check(false);
create policy automation_attempts_private on private.automation_attempts for all using(false) with check(false);
create policy automation_worker_private on private.automation_worker_state for all using(false) with check(false);
revoke all on private.automation_tasks,private.automation_attempts,private.automation_worker_state from public,anon,authenticated,service_role;

create function private.reminder_plan(consultation timestamptz,scheduled timestamptz,timezone text) returns timestamptz
language plpgsql stable security invoker set search_path='' as $$
declare due timestamptz;
begin
 if not isfinite(consultation) or not isfinite(scheduled) or consultation-scheduled<interval '24 hours' then return null; end if;
 due:=(((consultation at time zone timezone)::date-1)+time '08:00') at time zone timezone;
 if scheduled>due then return null; end if;
 return due;
end $$;

create function private.enqueue_automation() returns trigger
language plpgsql security definer set search_path='' as $$
declare due timestamptz; tz text; old_reminder private.automation_tasks; confirmation_only boolean:=false;
begin
 select timezone into tz from app.clinics where id=new.clinic_id;
 if tg_op='UPDATE' then
  confirmation_only:=old.status='agendada' and new.status='confirmada' and old.starts_at=new.starts_at and old.ends_at=new.ends_at;
  select * into old_reminder from private.automation_tasks where clinic_id=new.clinic_id and appointment_id=new.id and appointment_version=old.version and kind='whatsapp_reminder';
  update private.automation_attempts set finished_at=now(),outcome='cancelled'
   where finished_at is null and task_id in(select id from private.automation_tasks where clinic_id=new.clinic_id and appointment_id=new.id and status='processing');
  update private.automation_tasks set status='cancelled',reason='superseded',lease_token=null,lease_until=null,revision=revision+1,updated_at=now()
   where clinic_id=new.clinic_id and appointment_id=new.id and status in('pending','processing','retry','blocked','failed');
 end if;
 insert into private.automation_tasks(clinic_id,appointment_id,appointment_version,kind,due_at,available_at)
  values(new.clinic_id,new.id,new.version,'google_sync',now(),now()) on conflict do nothing;
 if new.status in('agendada','confirmada') then
  if confirmation_only then
   if old_reminder.id is not null and old_reminder.status not in('completed','failed')
    and (old_reminder.reason is null or old_reminder.reason='integration_not_configured') and old_reminder.due_at>=now() then due:=old_reminder.due_at; end if;
  else due:=private.reminder_plan(new.starts_at,now(),tz); end if;
  if due is not null then
   insert into private.automation_tasks(clinic_id,appointment_id,appointment_version,kind,due_at,available_at,expires_at)
    values(new.clinic_id,new.id,new.version,'whatsapp_reminder',due,due,new.starts_at) on conflict do nothing;
  end if;
 end if;
 return new;
end $$;
-- Existing history/occupancy triggers run first; queue failure rolls back the appointment too.
create trigger zz_appointment_automation after insert or update on app.appointments for each row execute function private.enqueue_automation();

-- The foundation cannot call an external provider or report a completed delivery.
create function private.automation_current(task private.automation_tasks,appointment app.appointments) returns boolean
language sql stable security invoker set search_path='' as $$
 select task.clinic_id=appointment.clinic_id and task.appointment_id=appointment.id and task.appointment_version=appointment.version
  and (task.kind='google_sync' or appointment.status in('agendada','confirmada'));
$$;
create function private.automation_context_live(task private.automation_tasks,appointment app.appointments) returns boolean
language sql stable security invoker set search_path='' as $$
 select exists(select 1 from app.clinics c where c.id=task.clinic_id and c.active)
  and (appointment.status='cancelada' and task.kind='google_sync' or exists(
   select 1 from app.memberships m join app.users u on u.id=m.user_id and u.active
   join app.membership_roles r on r.clinic_id=m.clinic_id and r.membership_id=m.id and r.role='doctor'
   where m.clinic_id=task.clinic_id and m.id=appointment.membership_id and m.active));
$$;
create function private.claim_automation(target_clinic uuid,batch_size integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare candidate record; task private.automation_tasks; appointment app.appointments; result jsonb:='[]'; token uuid; count_claimed integer:=0;
begin
 if target_clinic is null or batch_size is null or batch_size<1 or batch_size>50 then raise exception using errcode='22023',message='Invalid automation batch'; end if;
 for candidate in select t.id,t.appointment_id from private.automation_tasks t where t.clinic_id=target_clinic
  and ((t.status in('pending','retry') and t.available_at<=now()) or (t.status='processing' and t.lease_until<=now()))
  order by t.available_at,t.id limit 200
 loop
  -- Every worker locks appointment before task, matching the appointment trigger.
  select * into appointment from app.appointments where clinic_id=target_clinic and id=candidate.appointment_id for update skip locked;
  if not found then continue; end if;
  select * into task from private.automation_tasks where id=candidate.id for update skip locked;
  if not found or not((task.status in('pending','retry') and task.available_at<=now()) or (task.status='processing' and task.lease_until<=now())) then continue; end if;
  if not private.automation_current(task,appointment) or (task.expires_at is not null and task.expires_at<=now()) then
   update private.automation_attempts set finished_at=now(),outcome='cancelled' where task_id=task.id and finished_at is null;
   update private.automation_tasks set status='cancelled',reason=case when task.expires_at<=now() then 'expired' else 'superseded' end,lease_token=null,lease_until=null,revision=revision+1,updated_at=now() where id=task.id;
   continue;
  end if;
  if task.status='processing' then
   update private.automation_attempts set finished_at=now(),outcome=case when task.kind='whatsapp_reminder' then 'result_unknown' else 'lease_expired' end where task_id=task.id and finished_at is null;
   if task.kind='whatsapp_reminder' then
    update private.automation_tasks set status='blocked',reason='result_unknown',lease_token=null,lease_until=null,revision=revision+1,updated_at=now() where id=task.id;
    continue;
   end if;
  end if;
  if task.attempts>=5 or not private.automation_context_live(task,appointment) then
   update private.automation_tasks set status=case when task.attempts>=5 then 'failed' else 'blocked' end,reason=case when task.attempts>=5 then 'attempts_exhausted' else 'access_revoked' end,lease_token=null,lease_until=null,revision=revision+1,updated_at=now() where id=task.id;
   continue;
  end if;
  token:=gen_random_uuid();
  update private.automation_tasks set status='processing',attempts=attempts+1,lease_token=token,lease_until=now()+interval '2 minutes',revision=revision+1,updated_at=now(),reason=null where id=task.id returning * into task;
  insert into private.automation_attempts(task_id,number,token) values(task.id,task.attempts,token);
  result:=result||jsonb_build_array(jsonb_build_object('id',task.id,'clinic',task.clinic_id,'appointment',task.appointment_id,'version',task.appointment_version,'kind',task.kind,'lease',token,
   'intent',case when appointment.status='cancelada' then 'remove' else 'upsert' end,'key',task.clinic_id::text||':'||task.appointment_id::text||':'||task.kind||case when task.kind='whatsapp_reminder' then ':'||extract(epoch from appointment.starts_at)::bigint::text else '' end));
  count_claimed:=count_claimed+1; if count_claimed>=batch_size then exit; end if;
 end loop;
 return result;
end $$;
create function private.finish_automation(target_clinic uuid,target_task uuid,token uuid,outcome text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare task private.automation_tasks; appointment app.appointments; attempt private.automation_attempts; final_status text; reason_code text; delay_seconds integer;
begin
 if token is null or outcome is null or outcome not in('integration_not_configured','transient_failure','permanent_failure','result_unknown') then raise exception using errcode='22023',message='Invalid automation outcome'; end if;
 select appointment_id into task.appointment_id from private.automation_tasks where clinic_id=target_clinic and id=target_task;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 select * into appointment from app.appointments where clinic_id=target_clinic and id=task.appointment_id for update;
 select * into task from private.automation_tasks where clinic_id=target_clinic and id=target_task for update;
 select * into attempt from private.automation_attempts where task_id=task.id and automation_attempts.token=finish_automation.token;
 if attempt.finished_at is not null then return jsonb_build_object('status','already_finished'); end if;
 if task.status<>'processing' or task.lease_token is distinct from token or task.lease_until<=now() then return jsonb_build_object('status','conflict'); end if;
 if not private.automation_current(task,appointment) or task.expires_at<=now() then final_status:='cancelled';reason_code:='superseded';
 elsif not private.automation_context_live(task,appointment) then final_status:='blocked';reason_code:='access_revoked';
 elsif outcome='transient_failure' then
  if task.kind='whatsapp_reminder' then final_status:='blocked';reason_code:='retry_policy_pending';
  elsif task.attempts>=5 then final_status:='failed';reason_code:='attempts_exhausted';
  else final_status:='retry';reason_code:='transient_failure'; end if;
 elsif outcome='permanent_failure' then final_status:='failed';reason_code:=outcome;
 else final_status:='blocked';reason_code:=outcome; end if;
 delay_seconds:=least(1800,30*(2^(task.attempts-1))::integer);
 update private.automation_attempts set finished_at=now(),outcome=final_status where task_id=task.id and number=task.attempts;
 update private.automation_tasks set status=final_status,reason=reason_code,lease_token=null,lease_until=null,
  available_at=case when final_status='retry' then now()+delay_seconds*interval '1 second' else available_at end,revision=revision+1,updated_at=now() where id=task.id;
 return jsonb_build_object('status','saved');
end $$;

-- Worker entry points are exclusively callable with the technical role, never user JWTs.
grant usage on schema api,private to service_role;
create function private.worker_claim(target_clinic uuid,batch_size integer) returns jsonb
language plpgsql security definer set search_path='' as $$ begin
 if current_setting('role',true)<>'service_role' then raise exception using errcode='42501',message='Technical worker required'; end if;
 return private.claim_automation(target_clinic,batch_size);
end $$;
create function private.worker_finish(target_clinic uuid,target_task uuid,token uuid,outcome text) returns jsonb
language plpgsql security definer set search_path='' as $$ begin
 if current_setting('role',true)<>'service_role' then raise exception using errcode='42501',message='Technical worker required'; end if;
 return private.finish_automation(target_clinic,target_task,token,outcome);
end $$;
create function api.claim_automation(clinic_id uuid,batch_size integer) returns jsonb language sql security invoker set search_path='' as $$ select private.worker_claim($1,$2); $$;
create function api.finish_automation(clinic_id uuid,task_id uuid,lease_token uuid,outcome text) returns jsonb language sql security invoker set search_path='' as $$ select private.worker_finish($1,$2,$3,$4); $$;

create function private.process_foundation_jobs(batch_size integer default 25) returns integer
language plpgsql security definer set search_path='' as $$
declare clinic record; task jsonb; processed integer:=0;
begin
 if batch_size is null or batch_size<1 or batch_size>50 then raise exception using errcode='22023',message='Invalid automation batch'; end if;
 -- Bounded global work; no external requests, credentials or actor impersonation.
 for clinic in select distinct clinic_id from private.automation_tasks where (status in('pending','retry') and available_at<=now()) or (status='processing' and lease_until<=now()) order by clinic_id limit 50 loop
  for task in select value from jsonb_array_elements(private.claim_automation(clinic.clinic_id,least(batch_size-processed,10))) loop
   perform private.finish_automation(clinic.clinic_id,(task->>'id')::uuid,(task->>'lease')::uuid,'integration_not_configured'); processed:=processed+1;
  end loop;
  if processed>=batch_size then exit; end if;
 end loop;
 insert into private.automation_worker_state values('foundation',now(),processed) on conflict(name) do update set last_run_at=excluded.last_run_at,processed=excluded.processed;
 return processed;
end $$;

create function private.list_automations(target_clinic uuid,own_only boolean,page_number integer,target_appointment uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); result jsonb;
begin
 if own_only is null or page_number is null or page_number<0 or page_number>10000 then raise exception using errcode='22023',message='Invalid automation query'; end if;
 if own_only and permission->>'doctor_membership' is null then raise exception using errcode='42501',message='Access denied'; end if;
 select coalesce(jsonb_agg(item order by created_at desc,id),'[]') into result from(
  select t.id,t.created_at,jsonb_build_object('id',t.id,'appointment',t.appointment_id,'appointment_version',t.appointment_version,'doctor',a.membership_id,'doctor_name',u.display_name,
   'kind',t.kind,'status',t.status,'reason',t.reason,'attempts',t.attempts,'revision',t.revision,'due_local',to_char(t.due_at at time zone c.timezone,'YYYY-MM-DD"T"HH24:MI'),
   'updated_local',to_char(t.updated_at at time zone c.timezone,'YYYY-MM-DD"T"HH24:MI'),'available_local',to_char(t.available_at at time zone c.timezone,'YYYY-MM-DD"T"HH24:MI')) item
  from private.automation_tasks t join app.appointments a on a.clinic_id=t.clinic_id and a.id=t.appointment_id
  join app.memberships m on m.clinic_id=a.clinic_id and m.id=a.membership_id join app.users u on u.id=m.user_id join app.clinics c on c.id=t.clinic_id
  where t.clinic_id=target_clinic and (target_appointment is null or a.id=target_appointment) and private.agenda_allowed(permission,a.membership_id,own_only)
  order by t.created_at desc,t.id offset page_number*50 limit 51
 ) q;
 insert into audit.events(clinic_id,actor_user_id,action) values(target_clinic,(permission->>'actor')::uuid,'automation.viewed');
 return jsonb_build_object('records',(select coalesce(jsonb_agg(value),'[]') from jsonb_array_elements(result) with ordinality x(value,n) where n<=50),'has_more',jsonb_array_length(result)>50,'page',page_number,
  'worker',(select jsonb_build_object('last_run_local',to_char(last_run_at at time zone (select timezone from app.clinics where id=target_clinic),'YYYY-MM-DD"T"HH24:MI')) from private.automation_worker_state where name='foundation'));
end $$;
create function api.list_automations(clinic_id uuid,own_only boolean,page_number integer,appointment_id uuid default null) returns jsonb language sql security invoker set search_path='' as $$ select private.list_automations($1,$2,$3,$4); $$;

alter table audit.events drop constraint events_action_check;
alter table audit.events add constraint events_action_check check(action in
 ('clinic.selected','clinic.created','administrator.linked','administrator.invitation_cancelled','team.linked','administrator.doctor_configured',
 'patient.created','patient.updated','patient.viewed','patient.searched','patient.deleted','patient.archived','administrator.removed','team.removed','administrator.doctor_disabled',
 'availability.created','availability.removed','doctor.duration_updated','block.created','block.removed',
 'appointment.created','appointment.rescheduled','appointment.confirmed','appointment.completed','appointment.cancelled','appointment.no_show','appointment.replaced','agenda.viewed','appointment.viewed','automation.viewed'));

do $privileges$ declare item record; begin
 for item in select p.oid::regprocedure signature,p.proname,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in('private','api') and p.proname=any(array['reminder_plan','enqueue_automation','automation_current','automation_context_live','claim_automation','finish_automation','worker_claim','worker_finish','process_foundation_jobs','list_automations']) loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',item.signature);
  if item.proname='list_automations' then execute format('grant execute on function %s to authenticated',item.signature);
  elsif item.proname in('worker_claim','worker_finish') or (item.nspname='api' and item.proname in('claim_automation','finish_automation')) then execute format('grant execute on function %s to service_role',item.signature); end if;
 end loop;
end $privileges$;
comment on table private.automation_tasks is 'Transactional versioned automation outbox; references only, no patient or provider payload.';
comment on function private.process_foundation_jobs(integer) is 'Foundation processor only: records integration_not_configured, never sends messages or synchronizes events.';

-- Backfill only future active consultations. Historical records and patients stay untouched.
insert into private.automation_tasks(clinic_id,appointment_id,appointment_version,kind,due_at,available_at)
 select clinic_id,id,version,'google_sync',now(),now() from app.appointments where status in('agendada','confirmada') and starts_at>now() on conflict do nothing;
insert into private.automation_tasks(clinic_id,appointment_id,appointment_version,kind,due_at,available_at,expires_at)
 select a.clinic_id,a.id,a.version,'whatsapp_reminder',plan.due,plan.due,a.starts_at
 from app.appointments a join app.clinics c on c.id=a.clinic_id
 cross join lateral (select private.reminder_plan(a.starts_at,(select max(occurred_at) from app.appointment_history h where h.clinic_id=a.clinic_id and h.appointment_id=a.id and h.status='agendada'),c.timezone) due) plan
 where a.status in('agendada','confirmada') and plan.due>=now() on conflict do nothing;
