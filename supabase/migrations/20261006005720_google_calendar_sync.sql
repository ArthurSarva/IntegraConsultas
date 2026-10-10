-- Provider payloads are available only to server workers; patients never enter them.
alter table private.automation_tasks drop constraint automation_tasks_reason_check;
alter table private.automation_tasks add constraint automation_tasks_reason_check check(reason in('integration_not_configured','superseded','expired','access_revoked','transient_failure','permanent_failure','lease_expired','result_unknown','retry_policy_pending','attempts_exhausted','google_conflict'));
alter table private.automation_attempts drop constraint automation_attempts_outcome_check;
alter table private.automation_attempts add constraint automation_attempts_outcome_check check(outcome in('blocked','retry','failed','cancelled','lease_expired','result_unknown','completed'));

create function private.google_booking_window(target_clinic uuid,doctor uuid,local_start timestamp,duration integer,own_only boolean) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare p jsonb:=private.patient_permissions(target_clinic); first_instant timestamptz;
begin
 if not coalesce((p->>'can_write')::boolean,false) or not private.agenda_allowed(p,doctor,own_only) then raise exception using errcode='42501',message='Access denied'; end if;
 if duration is null or duration not in(15,30,45,60) then raise exception using errcode='22023',message='Invalid duration'; end if;
 first_instant:=private.agenda_instant(target_clinic,local_start);
 return jsonb_build_object('start',first_instant,'end',first_instant+duration*interval '1 minute','connected',exists(select 1 from private.google_connections where clinic_id=target_clinic and membership_id=doctor));
end $$;
create function api.google_booking_window(clinic_id uuid,doctor_id uuid,start_local timestamp,duration_minutes integer,own_only boolean) returns jsonb language sql security invoker set search_path='' as $$ select private.google_booking_window($1,$2,$3,$4,$5); $$;

create function private.google_load_connection(target_clinic uuid,doctor uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare result jsonb;
begin
 if current_setting('role',true)<>'service_role' then raise exception using errcode='42501',message='Technical worker required'; end if;
 select jsonb_build_object('credential',g.credential,'calendar',g.calendar_id,'connected_at',g.connected_at) into result
 from private.google_connections g join app.clinics c on c.id=g.clinic_id and c.active
 join app.memberships m on m.clinic_id=g.clinic_id and m.id=g.membership_id and m.active
 join app.users u on u.id=m.user_id and u.active
 join app.membership_roles r on r.clinic_id=m.clinic_id and r.membership_id=m.id and r.role='doctor'
 where g.clinic_id=target_clinic and g.membership_id=doctor;
 return result;
end $$;
create function api.google_load_connection(clinic_id uuid,doctor_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.google_load_connection($1,$2); $$;

create function private.google_task_payload(target_clinic uuid,target_task uuid,token uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare t private.automation_tasks; a app.appointments; connection jsonb;
begin
 if current_setting('role',true)<>'service_role' then raise exception using errcode='42501',message='Technical worker required'; end if;
 select * into t from private.automation_tasks where clinic_id=target_clinic and id=target_task and kind='google_sync' and status='processing' and lease_token=token and lease_until>now();
 if not found then return null; end if;
 select * into a from app.appointments where clinic_id=t.clinic_id and id=t.appointment_id;
 if not private.automation_current(t,a) or not private.automation_context_live(t,a) then return null; end if;
 connection:=private.google_load_connection(t.clinic_id,a.membership_id);if connection is null then return null; end if;
 return connection||jsonb_build_object('clinic',a.clinic_id,'membership',a.membership_id,'appointment',a.id,'version',a.version,'start',a.starts_at,'end',a.ends_at,'status',a.status,'replaces',a.replaces_id);
end $$;
create function api.google_task_payload(clinic_id uuid,task_id uuid,lease_token uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.google_task_payload($1,$2,$3); $$;

create function private.google_finish_task(target_clinic uuid,target_task uuid,token uuid,outcome text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare t private.automation_tasks; a app.appointments; next_status text;
begin
 if current_setting('role',true)<>'service_role' then raise exception using errcode='42501',message='Technical worker required'; end if;
 if outcome is null or outcome not in('completed','google_conflict','integration_not_configured','transient_failure','permanent_failure') then raise exception using errcode='22023',message='Invalid outcome'; end if;
 select appointment_id into t.appointment_id from private.automation_tasks where clinic_id=target_clinic and id=target_task and kind='google_sync';
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 select * into a from app.appointments where clinic_id=target_clinic and id=t.appointment_id for update;
 select * into t from private.automation_tasks where clinic_id=target_clinic and id=target_task for update;
 if t.status<>'processing' or t.lease_token is distinct from token or t.lease_until<=now() then return jsonb_build_object('status','conflict'); end if;
 if outcome not in('completed','google_conflict') then return private.finish_automation(target_clinic,target_task,token,outcome); end if;
 next_status:=case when not private.automation_current(t,a) then 'cancelled' when not private.automation_context_live(t,a) then 'blocked' when outcome='completed' then 'completed' else 'blocked' end;
 update private.automation_attempts set finished_at=now(),outcome=next_status where task_id=t.id and number=t.attempts;
 update private.automation_tasks set status=next_status,reason=case when next_status='cancelled' then 'superseded' when next_status='blocked' then case when outcome='google_conflict' then outcome else 'access_revoked' end else null end,
 lease_token=null,lease_until=null,revision=revision+1,updated_at=now() where id=t.id;
 return jsonb_build_object('status','saved');
end $$;
create function api.google_finish_task(clinic_id uuid,task_id uuid,lease_token uuid,outcome text) returns jsonb language sql security invoker set search_path='' as $$ select private.google_finish_task($1,$2,$3,$4); $$;

-- Revisit only current tasks blocked before the connection became available.
create function private.google_worker_clinics() returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb;
begin
 if current_setting('role',true)<>'service_role' then raise exception using errcode='42501',message='Technical worker required'; end if;
 update private.automation_tasks t set status='pending',reason=null,available_at=now(),revision=revision+1,updated_at=now()
 from app.appointments a,private.google_connections g where t.clinic_id=a.clinic_id and t.appointment_id=a.id and t.appointment_version=a.version
 and g.clinic_id=a.clinic_id and g.membership_id=a.membership_id and t.kind='google_sync' and t.status='blocked' and t.reason='integration_not_configured' and t.updated_at<g.connected_at and t.attempts<5;
 select coalesce(jsonb_agg(clinic_id),'[]') into result from(select distinct t.clinic_id from private.automation_tasks t join app.appointments a on a.clinic_id=t.clinic_id and a.id=t.appointment_id
 join private.google_connections g on g.clinic_id=a.clinic_id and g.membership_id=a.membership_id where t.kind='google_sync' and ((t.status in('pending','retry') and t.available_at<=now()) or(t.status='processing' and t.lease_until<=now())) order by t.clinic_id limit 20) q;
 return result;
end $$;
create function api.google_worker_clinics() returns jsonb language sql security invoker set search_path='' as $$ select private.google_worker_clinics(); $$;

do $privileges$ declare f record; begin
 for f in select p.oid::regprocedure signature,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('api','private') and p.proname=any(array['google_booking_window','google_load_connection','google_task_payload','google_finish_task','google_worker_clinics']) loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
 execute format('grant execute on function %s to %I',f.signature,case when f.proname='google_booking_window' then 'authenticated' else 'service_role' end);
 end loop;
end $privileges$;

create function private.claim_selected_automation(target_clinic uuid,batch_size integer,selected_kind text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare candidate record; task private.automation_tasks; appointment app.appointments; result jsonb:='[]'; token uuid; count_claimed integer:=0;
begin
 if target_clinic is null or batch_size is null or batch_size<1 or batch_size>50 then raise exception using errcode='22023',message='Invalid automation batch'; end if;
 for candidate in select t.id,t.appointment_id from private.automation_tasks t where t.clinic_id=target_clinic and (selected_kind is null or t.kind=selected_kind) and (selected_kind is not null or t.kind<>'google_sync' or not exists(select 1 from app.appointments a join private.google_connections g on g.clinic_id=a.clinic_id and g.membership_id=a.membership_id where a.clinic_id=t.clinic_id and a.id=t.appointment_id)) and (selected_kind is null or not exists(select 1 from private.automation_attempts x join private.automation_tasks prior on prior.id=x.task_id where prior.clinic_id=t.clinic_id and prior.appointment_id=t.appointment_id and prior.kind='google_sync' and x.started_at>now()-interval '2 minutes' and (x.finished_at is null or x.outcome='cancelled')))
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

create or replace function private.claim_automation(target_clinic uuid,batch_size integer) returns jsonb language sql security definer set search_path='' as $$ select private.claim_selected_automation($1,$2,null); $$;
create function private.google_claim_tasks(target_clinic uuid,batch_size integer) returns jsonb language plpgsql security definer set search_path='' as $$ begin if current_setting('role',true)<>'service_role' then raise exception using errcode='42501',message='Technical worker required'; end if; return private.claim_selected_automation(target_clinic,batch_size,'google_sync'); end $$;
create function api.google_claim_tasks(clinic_id uuid,batch_size integer) returns jsonb language sql security invoker set search_path='' as $$ select private.google_claim_tasks($1,$2); $$;
revoke all on function private.claim_selected_automation(uuid,integer,text),private.google_claim_tasks(uuid,integer),api.google_claim_tasks(uuid,integer) from public,anon,authenticated,service_role;
grant execute on function private.google_claim_tasks(uuid,integer),api.google_claim_tasks(uuid,integer) to service_role;
