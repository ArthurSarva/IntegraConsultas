create schema if not exists extensions;
create extension if not exists btree_gist with schema extensions;

create table app.availability_windows (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, membership_id uuid not null,
 weekday integer not null check(weekday between 0 and 6), starts_at time not null, ends_at time not null,
 active boolean not null default true, version integer not null default 1 check(version>0),
 check(starts_at<ends_at and extract(second from starts_at)=0 and extract(second from ends_at)=0),
 unique(clinic_id,id), foreign key(clinic_id,membership_id) references app.memberships(clinic_id,id) on delete restrict
);
create index availability_doctor_idx on app.availability_windows(clinic_id,membership_id,weekday) where active;
create table app.agenda_blocks (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, membership_id uuid not null,
 starts_at timestamptz not null, ends_at timestamptz not null, active boolean not null default true,
 version integer not null default 1 check(version>0),
 check(isfinite(starts_at) and isfinite(ends_at) and starts_at<ends_at and ends_at-starts_at<=interval '31 days'),
 unique(clinic_id,id), foreign key(clinic_id,membership_id) references app.memberships(clinic_id,id) on delete restrict
);
create index agenda_blocks_doctor_idx on app.agenda_blocks(clinic_id,membership_id,starts_at) where active;
create table app.appointments (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, membership_id uuid not null, patient_id uuid not null,
 starts_at timestamptz not null, ends_at timestamptz not null,
 duration_minutes integer not null check(duration_minutes in(15,30,45,60)),
 status text not null default 'agendada' check(status in('agendada','confirmada','concluida','cancelada','falta')),
 version integer not null default 1 check(version>0), confirmed_at timestamptz, replaces_id uuid,
 created_at timestamptz not null default now(), updated_at timestamptz not null default now(),
 check(isfinite(starts_at) and isfinite(ends_at) and ends_at=starts_at+duration_minutes*interval '1 minute'),
 check((status='confirmada')=(confirmed_at is not null)),
 unique(clinic_id,id), unique(clinic_id,replaces_id),
 foreign key(clinic_id,membership_id) references app.memberships(clinic_id,id) on delete restrict,
 foreign key(clinic_id,patient_id) references app.patients(clinic_id,id) on delete restrict,
 foreign key(clinic_id,patient_id) references app.patient_references(clinic_id,id) on delete restrict,
 foreign key(clinic_id,replaces_id) references app.appointments(clinic_id,id) on delete restrict
);
create index appointments_agenda_idx on app.appointments(clinic_id,starts_at,id);
create index appointments_doctor_idx on app.appointments(clinic_id,membership_id,starts_at,id);
create index appointments_patient_idx on app.appointments(clinic_id,patient_id,starts_at desc,id);
create table app.appointment_history (
 clinic_id uuid not null, appointment_id uuid not null, version integer not null, status text not null,
 starts_at timestamptz not null, ends_at timestamptz not null, duration_minutes integer not null,
 actor_user_id uuid not null references app.users(id), occurred_at timestamptz not null default now(),
 primary key(clinic_id,appointment_id,version),
 foreign key(clinic_id,appointment_id) references app.appointments(clinic_id,id) on delete restrict
);
-- Minimal global projection: no clinic, patient, names or external event contents.
create table private.agenda_occupancy (
 resource_id uuid primary key, physician_id uuid not null references app.users(id), occupied tstzrange not null,
 check(not isempty(occupied) and not lower_inf(occupied) and not upper_inf(occupied) and lower_inc(occupied) and not upper_inc(occupied)),
 exclude using gist(physician_id extensions.gist_uuid_ops with =, occupied with &&)
);
create table private.agenda_requests (
 operation_id uuid primary key, clinic_id uuid not null references app.clinics(id), actor_user_id uuid not null references app.users(id),
 fingerprint text not null, result jsonb not null
);
alter table audit.events add column target_appointment_id uuid;
alter table audit.events add foreign key(clinic_id,target_appointment_id) references app.appointments(clinic_id,id) on delete restrict;
alter table audit.events drop constraint events_action_check;
alter table audit.events add constraint events_action_check check(action in
 ('clinic.selected','clinic.created','administrator.linked','administrator.invitation_cancelled','team.linked','administrator.doctor_configured',
 'patient.created','patient.updated','patient.viewed','patient.searched','patient.deleted','patient.archived','administrator.removed','team.removed','administrator.doctor_disabled',
 'availability.created','availability.removed','doctor.duration_updated','block.created','block.removed',
 'appointment.created','appointment.rescheduled','appointment.confirmed','appointment.completed','appointment.cancelled','appointment.no_show','appointment.replaced','agenda.viewed','appointment.viewed'));

alter table app.availability_windows enable row level security;
alter table app.agenda_blocks enable row level security;
alter table app.appointments enable row level security;
alter table app.appointment_history enable row level security;
alter table private.agenda_occupancy enable row level security;
alter table private.agenda_requests enable row level security;
create policy availability_no_direct_access on app.availability_windows for all using(false) with check(false);
create policy blocks_no_direct_access on app.agenda_blocks for all using(false) with check(false);
create policy appointments_no_direct_access on app.appointments for all using(false) with check(false);
create policy history_no_direct_access on app.appointment_history for all using(false) with check(false);
create policy occupancy_no_direct_access on private.agenda_occupancy for all using(false) with check(false);
create policy requests_no_direct_access on private.agenda_requests for all using(false) with check(false);
revoke all on app.availability_windows,app.agenda_blocks,app.appointments,app.appointment_history,private.agenda_occupancy,private.agenda_requests from public,anon,authenticated,service_role;

create function private.project_agenda_occupancy() returns trigger
language plpgsql security definer set search_path='' as $$
declare physician uuid; occupies boolean;
begin
 if tg_op='DELETE' then delete from private.agenda_occupancy where resource_id=old.id; return old; end if;
 select user_id into physician from app.memberships where clinic_id=new.clinic_id and id=new.membership_id;
 if tg_table_name='appointments' then occupies:=new.status in('agendada','confirmada'); else occupies:=new.active; end if;
 if occupies then
  insert into private.agenda_occupancy(resource_id,physician_id,occupied) values(new.id,physician,tstzrange(new.starts_at,new.ends_at,'[)'))
   on conflict(resource_id) do update set physician_id=excluded.physician_id,occupied=excluded.occupied;
 else delete from private.agenda_occupancy where resource_id=new.id; end if;
 return new;
end $$;
-- Reads never expose the global projection or another clinic's records.
create function private.agenda_doctors(target_clinic uuid,own_only boolean) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); result jsonb;
begin
 if own_only is null or (own_only and permission->>'doctor_membership' is null) then raise exception using errcode='42501',message='Access denied'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',m.id,'name',u.display_name,'duration',coalesce(d.default_duration_minutes,30)) order by u.display_name,m.id),'[]'::jsonb) into result
 from app.memberships m join app.users u on u.id=m.user_id and u.active
 join app.membership_roles r on r.clinic_id=m.clinic_id and r.membership_id=m.id and r.role='doctor'
 left join app.doctor_settings d on d.clinic_id=m.clinic_id and d.membership_id=m.id
 where m.clinic_id=target_clinic and m.active and private.agenda_allowed(permission,m.id,own_only);
 return result;
end $$;
create function private.appointment_json(appointment uuid) returns jsonb
language sql stable security definer set search_path='' as $$
 select jsonb_build_object('id',a.id,'doctor',a.membership_id,'doctor_name',u.display_name,'patient',a.patient_id,'patient_name',p.display_name,'patient_archived',p.archived_at is not null,
 'starts_at',a.starts_at,'ends_at',a.ends_at,'start_local',to_char(a.starts_at at time zone c.timezone,'YYYY-MM-DD"T"HH24:MI'),
 'end_local',to_char(a.ends_at at time zone c.timezone,'YYYY-MM-DD"T"HH24:MI'),'duration',a.duration_minutes,'status',a.status,'version',a.version,'replaces_id',a.replaces_id)
 from app.appointments a join app.clinics c on c.id=a.clinic_id join app.patients p on p.clinic_id=a.clinic_id and p.id=a.patient_id
 join app.memberships m on m.clinic_id=a.clinic_id and m.id=a.membership_id join app.users u on u.id=m.user_id where a.id=appointment;
$$;
create function private.list_agenda(target_clinic uuid,day date,doctor uuid,own_only boolean,page_number integer) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); zone text; first_instant timestamptz; last_instant timestamptz; records jsonb; blocks jsonb; more boolean;
begin
 if day is null or not isfinite(day) or page_number is null or page_number not between 0 and 10000 then raise exception using errcode='22023',message='Invalid agenda query'; end if;
 if own_only is null or (own_only and permission->>'doctor_membership' is null)
  or (doctor is not null and (not private.agenda_allowed(permission,doctor,own_only) or not exists(select 1 from app.memberships where clinic_id=target_clinic and id=doctor))) then raise exception using errcode='42501',message='Access denied'; end if;
 select timezone into zone from app.clinics where id=target_clinic;
 first_instant:=day::timestamp at time zone zone; last_instant:=(day+1)::timestamp at time zone zone;
 select coalesce(jsonb_agg(private.appointment_json(q.id) order by q.starts_at,q.id),'[]'::jsonb) into records from
  (select a.id,a.starts_at from app.appointments a where a.clinic_id=target_clinic and a.starts_at>=first_instant and a.starts_at<last_instant
   and (doctor is null or a.membership_id=doctor) and private.agenda_allowed(permission,a.membership_id,own_only) order by a.starts_at,a.id limit 50 offset page_number*50) q;
 select exists(select 1 from app.appointments a where a.clinic_id=target_clinic and a.starts_at>=first_instant and a.starts_at<last_instant
  and (doctor is null or a.membership_id=doctor) and private.agenda_allowed(permission,a.membership_id,own_only) offset (page_number+1)*50) into more;
 select coalesce(jsonb_agg(jsonb_build_object('id',b.id,'doctor',b.membership_id,'doctor_name',u.display_name,'version',b.version,
  'start_local',to_char(b.starts_at at time zone zone,'YYYY-MM-DD"T"HH24:MI'),'end_local',to_char(b.ends_at at time zone zone,'YYYY-MM-DD"T"HH24:MI')) order by b.starts_at,b.id),'[]'::jsonb) into blocks
 from app.agenda_blocks b join app.memberships m on m.clinic_id=b.clinic_id and m.id=b.membership_id join app.users u on u.id=m.user_id
 where b.clinic_id=target_clinic and b.active and b.starts_at<last_instant and b.ends_at>first_instant
 and (doctor is null or b.membership_id=doctor) and private.agenda_allowed(permission,b.membership_id,own_only);
 insert into audit.events(clinic_id,actor_user_id,action) values(target_clinic,private.active_user_id(),'agenda.viewed');
 return jsonb_build_object('records',records,'blocks',blocks,'page',page_number,'has_more',more);
end $$;
create function private.get_appointment(target_clinic uuid,appointment uuid,own_only boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); item app.appointments%rowtype; history jsonb;
begin
 select * into item from app.appointments where clinic_id=target_clinic and id=appointment;
 if not found or not private.agenda_allowed(permission,item.membership_id,own_only) then return null; end if;
 select coalesce(jsonb_agg(jsonb_build_object('version',h.version,'status',h.status,
  'start_local',to_char(h.starts_at at time zone c.timezone,'YYYY-MM-DD"T"HH24:MI'),'duration',h.duration_minutes,'occurred_at',h.occurred_at) order by h.version),'[]'::jsonb) into history
 from app.appointment_history h join app.clinics c on c.id=h.clinic_id where h.clinic_id=target_clinic and h.appointment_id=appointment;
 insert into audit.events(clinic_id,actor_user_id,action,target_appointment_id,target_patient_id) values(target_clinic,private.active_user_id(),'appointment.viewed',item.id,item.patient_id);
 return private.appointment_json(item.id)||jsonb_build_object('history',history);
end $$;
create function private.agenda_availability(target_clinic uuid,doctor uuid,own_only boolean) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); result jsonb;
begin
 if not private.agenda_allowed(permission,doctor,own_only) or not exists(select 1 from app.memberships where clinic_id=target_clinic and id=doctor) then raise exception using errcode='42501',message='Access denied'; end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',w.id,'weekday',w.weekday,'start_time',left(w.starts_at::text,5),'end_time',left(w.ends_at::text,5),'version',w.version) order by w.weekday,w.starts_at,w.id),'[]'::jsonb) into result
 from app.availability_windows w where w.clinic_id=target_clinic and w.membership_id=doctor and w.active;
 return result;
end $$;
create function private.patient_appointments(target_clinic uuid,patient uuid,own_only boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); result jsonb;
begin
 if not private.can_read_patient(target_clinic,patient,own_only) then raise exception using errcode='42501',message='Access denied'; end if;
 select coalesce(jsonb_agg(private.appointment_json(q.id) order by q.starts_at desc,q.id),'[]'::jsonb) into result from
  (select a.id,a.starts_at from app.appointments a where a.clinic_id=target_clinic and a.patient_id=patient and private.agenda_allowed(permission,a.membership_id,own_only)
   order by a.starts_at desc,a.id limit 20) q;
 insert into audit.events(clinic_id,actor_user_id,action,target_patient_id) values(target_clinic,private.active_user_id(),'agenda.viewed',patient);
 return result;
end $$;
create function private.set_my_consultation_duration(target_clinic uuid,duration integer,operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); member uuid:=(permission->>'doctor_membership')::uuid; fingerprint text; prior jsonb;
begin
 permission:=private.lock_agenda_writer(target_clinic,member,true,operation_id,true,false);
 if duration is null or duration not in(15,30,45,60) then raise exception using errcode='22023',message='Invalid duration'; end if;
 fingerprint:=encode(sha256(convert_to(jsonb_build_array('duration',target_clinic,member,duration)::text,'UTF8')),'hex');
 prior:=private.agenda_replay(target_clinic,operation_id,fingerprint); if prior is not null then return prior; end if;
 insert into app.doctor_settings(clinic_id,membership_id,default_duration_minutes) values(target_clinic,member,duration)
  on conflict(clinic_id,membership_id) do update set default_duration_minutes=excluded.default_duration_minutes;
 return private.finish_agenda_operation(target_clinic,operation_id,fingerprint,'doctor.duration_updated',jsonb_build_object('status','saved'));
end $$;
create trigger appointment_occupancy after insert or update or delete on app.appointments for each row execute function private.project_agenda_occupancy();
create trigger block_occupancy after insert or update or delete on app.agenda_blocks for each row execute function private.project_agenda_occupancy();
create function private.record_appointment_history() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 insert into app.appointment_history(clinic_id,appointment_id,version,status,starts_at,ends_at,duration_minutes,actor_user_id)
 values(new.clinic_id,new.id,new.version,new.status,new.starts_at,new.ends_at,new.duration_minutes,private.active_user_id());
 return new;
end $$;
create trigger appointment_history after insert or update on app.appointments for each row execute function private.record_appointment_history();

create function private.agenda_allowed(permission jsonb,doctor uuid,own_only boolean) returns boolean
language sql immutable security invoker set search_path='' as $$
 select own_only is not null and doctor is not null and
 ((permission->>'scope'='clinic' and not own_only) or doctor=(permission->>'doctor_membership')::uuid);
$$;
-- All agenda writes use the same order: operation, identities, memberships, roles, physician, patients.
create function private.lock_agenda_writer(target_clinic uuid,doctor uuid,own_only boolean,operation_id uuid,require_doctor boolean default true,require_write boolean default true) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); actor uuid:=(permission->>'actor')::uuid; physician uuid; actor_member uuid;
begin
 if (require_write and not(permission->>'can_write')::boolean) or (not require_write and doctor is distinct from (permission->>'doctor_membership')::uuid)
  or not private.agenda_allowed(permission,doctor,own_only) then raise exception using errcode='42501',message='Access denied'; end if;
 if operation_id is null then raise exception using errcode='22023',message='Invalid agenda operation'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(operation_id::text,0));
 select user_id into physician from app.memberships where clinic_id=target_clinic and id=doctor;
 if physician is null then raise exception using errcode='42501',message='Access denied'; end if;
 perform 1 from app.users where id in(actor,physician) order by id for share;
 select id into actor_member from app.memberships where clinic_id=target_clinic and user_id=actor;
 perform 1 from app.memberships where clinic_id=target_clinic and id in(actor_member,doctor) order by id for share;
 perform 1 from app.membership_roles where clinic_id=target_clinic and membership_id in(actor_member,doctor) order by membership_id,role for share;
 permission:=private.patient_permissions(target_clinic);
 if (require_write and not(permission->>'can_write')::boolean) or (not require_write and doctor is distinct from (permission->>'doctor_membership')::uuid)
  or not private.agenda_allowed(permission,doctor,own_only) then raise exception using errcode='42501',message='Access denied'; end if;
 if require_doctor and not exists(select 1 from app.memberships m join app.users u on u.id=m.user_id and u.active
  join app.membership_roles r on r.clinic_id=m.clinic_id and r.membership_id=m.id and r.role='doctor'
  where m.clinic_id=target_clinic and m.id=doctor and m.active) then raise exception using errcode='42501',message='Access denied'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('agenda:'||physician::text,0));
 return permission||jsonb_build_object('physician',physician);
end $$;
create function private.agenda_replay(target_clinic uuid,operation_id uuid,fingerprint text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare prior private.agenda_requests%rowtype;
begin
 select * into prior from private.agenda_requests r where r.operation_id=agenda_replay.operation_id;
 if found then
  if prior.clinic_id<>target_clinic or prior.actor_user_id<>private.active_user_id() or prior.fingerprint<>fingerprint then raise exception using errcode='42501',message='Access denied'; end if;
  return prior.result;
 end if;
 if exists(select 1 from audit.events where request_id=operation_id) then raise exception using errcode='42501',message='Access denied'; end if;
 return null;
end $$;
create function private.finish_agenda_operation(target_clinic uuid,operation_id uuid,fingerprint text,action_name text,result jsonb,appointment uuid default null,patient uuid default null) returns jsonb
language plpgsql security definer set search_path='' as $$
begin
 insert into private.agenda_requests values(operation_id,target_clinic,private.active_user_id(),fingerprint,result);
 insert into audit.events(clinic_id,actor_user_id,action,request_id,request_fingerprint,target_appointment_id,target_patient_id)
  values(target_clinic,private.active_user_id(),action_name,operation_id,fingerprint,appointment,patient);
 return result;
end $$;
create function private.agenda_instant(target_clinic uuid,local_time timestamp) returns timestamptz
language plpgsql stable security definer set search_path='' as $$
declare zone text; instant timestamptz;
begin
 if local_time is null or not isfinite(local_time) or extract(second from local_time)<>0 then raise exception using errcode='22023',message='Invalid local time'; end if;
 select timezone into zone from app.clinics where id=target_clinic;
 instant:=local_time at time zone zone;
 if instant at time zone zone<>local_time then raise exception using errcode='22023',message='Invalid local time'; end if;
 return instant;
end $$;

create function private.change_availability(target_clinic uuid,doctor uuid,window_id uuid,day_of_week integer,start_time time,end_time time,expected_version integer,own_only boolean,operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.lock_agenda_writer(target_clinic,doctor,own_only,operation_id); fingerprint text; prior jsonb; item app.availability_windows%rowtype;
begin
 fingerprint:=encode(sha256(convert_to(jsonb_build_array('availability',target_clinic,doctor,window_id,day_of_week,start_time,end_time,expected_version,own_only)::text,'UTF8')),'hex');
 prior:=private.agenda_replay(target_clinic,operation_id,fingerprint); if prior is not null then return prior; end if;
 if window_id is null then
  if day_of_week is null or day_of_week not between 0 and 6 or start_time is null or end_time is null or start_time>=end_time
   or extract(second from start_time)<>0 or extract(second from end_time)<>0 or expected_version is not null then raise exception using errcode='22023',message='Invalid availability'; end if;
  if exists(select 1 from app.availability_windows w where w.clinic_id=target_clinic and w.membership_id=doctor and w.weekday=day_of_week and w.active and w.starts_at<end_time and start_time<w.ends_at) then return jsonb_build_object('status','occupied'); end if;
  insert into app.availability_windows(clinic_id,membership_id,weekday,starts_at,ends_at) values(target_clinic,doctor,day_of_week,start_time,end_time) returning * into item;
 else
  if expected_version is null or expected_version<1 then raise exception using errcode='22023',message='Invalid availability'; end if;
  select * into item from app.availability_windows where clinic_id=target_clinic and membership_id=doctor and id=window_id for update;
  if not found then raise exception using errcode='42501',message='Access denied'; end if;
  if not item.active or item.version<>expected_version then return jsonb_build_object('status','conflict'); end if;
  update app.availability_windows set active=false,version=version+1 where id=item.id returning * into item;
 end if;
 return private.finish_agenda_operation(target_clinic,operation_id,fingerprint,case when window_id is null then 'availability.created' else 'availability.removed' end,jsonb_build_object('status','saved','id',item.id,'version',item.version));
end $$;
create function private.change_agenda_block(target_clinic uuid,doctor uuid,block_id uuid,start_local timestamp,end_local timestamp,expected_version integer,own_only boolean,operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.lock_agenda_writer(target_clinic,doctor,own_only,operation_id,block_id is null); fingerprint text; prior jsonb; item app.agenda_blocks%rowtype; first_instant timestamptz; last_instant timestamptz;
begin
 fingerprint:=encode(sha256(convert_to(jsonb_build_array('block',target_clinic,doctor,block_id,start_local,end_local,expected_version,own_only)::text,'UTF8')),'hex');
 prior:=private.agenda_replay(target_clinic,operation_id,fingerprint); if prior is not null then return prior; end if;
 if block_id is null then
  first_instant:=private.agenda_instant(target_clinic,start_local); last_instant:=private.agenda_instant(target_clinic,end_local);
  if last_instant<=first_instant or last_instant<=now() or last_instant-first_instant>interval '31 days' or expected_version is not null then raise exception using errcode='22023',message='Invalid block'; end if;
  if exists(select 1 from private.agenda_occupancy where physician_id=(permission->>'physician')::uuid and occupied && tstzrange(first_instant,last_instant,'[)')) then return jsonb_build_object('status','occupied'); end if;
  insert into app.agenda_blocks(clinic_id,membership_id,starts_at,ends_at) values(target_clinic,doctor,first_instant,last_instant) returning * into item;
 else
  if expected_version is null or expected_version<1 then raise exception using errcode='22023',message='Invalid block'; end if;
  select * into item from app.agenda_blocks where clinic_id=target_clinic and membership_id=doctor and id=block_id for update;
  if not found then raise exception using errcode='42501',message='Access denied'; end if;
  if not item.active or item.version<>expected_version then return jsonb_build_object('status','conflict'); end if;
  update app.agenda_blocks set active=false,version=version+1 where id=item.id returning * into item;
 end if;
 return private.finish_agenda_operation(target_clinic,operation_id,fingerprint,case when block_id is null then 'block.created' else 'block.removed' end,jsonb_build_object('status','saved','id',item.id,'version',item.version));
end $$;

create function private.save_appointment(target_clinic uuid,doctor uuid,patient uuid,appointment uuid,start_local timestamp,duration integer,expected_version integer,replace_id uuid,replace_version integer,own_only boolean,operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.lock_agenda_writer(target_clinic,doctor,own_only,operation_id); fingerprint text; prior jsonb;
 item app.appointments%rowtype; replaced app.appointments%rowtype; instant timestamptz; finish timestamptz; zone text; default_duration integer; action_name text;
begin
 fingerprint:=encode(sha256(convert_to(jsonb_build_array('appointment',target_clinic,doctor,patient,appointment,start_local,duration,expected_version,replace_id,replace_version,own_only)::text,'UTF8')),'hex');
 prior:=private.agenda_replay(target_clinic,operation_id,fingerprint); if prior is not null then return prior; end if;
 if patient is null or duration is null or duration not in(15,30,45,60)
  or (appointment is null and expected_version is not null) or (appointment is not null and (expected_version is null or expected_version<1))
  or (replace_id is null and replace_version is not null) or (replace_id is not null and (appointment is not null or replace_version is null or replace_version<1)) then raise exception using errcode='22023',message='Invalid appointment'; end if;
 if appointment is not null then
  select * into item from app.appointments where clinic_id=target_clinic and membership_id=doctor and id=appointment for update;
  if not found or item.patient_id<>patient then raise exception using errcode='42501',message='Access denied'; end if;
  if item.version<>expected_version or item.status not in('agendada','confirmada') then return jsonb_build_object('status','conflict'); end if;
 end if;
 select default_duration_minutes into default_duration from app.doctor_settings where clinic_id=target_clinic and membership_id=doctor for share;
 if default_duration is null then default_duration:=30; end if;
 if duration<>default_duration and doctor is distinct from (permission->>'doctor_membership')::uuid and (appointment is null or duration<>item.duration_minutes) then raise exception using errcode='42501',message='Access denied'; end if;
 if not private.can_read_patient(target_clinic,patient,own_only) then raise exception using errcode='42501',message='Access denied'; end if;
 instant:=private.agenda_instant(target_clinic,start_local); finish:=instant+duration*interval '1 minute';
 if instant<=now() then raise exception using errcode='22023',message='Invalid appointment time'; end if;
 select timezone into zone from app.clinics where id=target_clinic;
 if (finish at time zone zone)::date<>start_local::date or not exists(select 1 from app.availability_windows w
  where w.clinic_id=target_clinic and w.membership_id=doctor and w.active and w.weekday=extract(dow from start_local)::integer
  and w.starts_at<=start_local::time and w.ends_at>=(finish at time zone zone)::time) then return jsonb_build_object('status','unavailable'); end if;
 if replace_id is not null then
  select * into replaced from app.appointments where clinic_id=target_clinic and membership_id=doctor and id=replace_id for update;
  if not found then raise exception using errcode='42501',message='Access denied'; end if;
  if replaced.version<>replace_version or replaced.status not in('agendada','confirmada') then return jsonb_build_object('status','conflict'); end if;
  if not(tstzrange(replaced.starts_at,replaced.ends_at,'[)') && tstzrange(instant,finish,'[)')) then raise exception using errcode='22023',message='Invalid replacement'; end if;
 end if;
 if exists(select 1 from private.agenda_occupancy o where o.physician_id=(permission->>'physician')::uuid and o.occupied && tstzrange(instant,finish,'[)')
  and o.resource_id is distinct from appointment and o.resource_id is distinct from replace_id) then return jsonb_build_object('status','occupied'); end if;
 -- Retention and assignment are part of the same successful scheduling transaction.
 perform private.retain_patient_for_consultation(target_clinic,patient);
 if not private.can_read_patient(target_clinic,patient,own_only) then raise exception using errcode='42501',message='Access denied'; end if;
 if replace_id is not null then
  update app.appointments set status='cancelada',confirmed_at=null,version=version+1,updated_at=now() where id=replaced.id;
  insert into audit.events(clinic_id,actor_user_id,action,target_appointment_id,target_patient_id)
   values(target_clinic,private.active_user_id(),'appointment.cancelled',replaced.id,replaced.patient_id);
 end if;
 if appointment is null then
  insert into app.appointments(clinic_id,membership_id,patient_id,starts_at,ends_at,duration_minutes,replaces_id)
   values(target_clinic,doctor,patient,instant,finish,duration,replace_id) returning * into item;
  action_name:=case when replace_id is null then 'appointment.created' else 'appointment.replaced' end;
 else
  update app.appointments set starts_at=instant,ends_at=finish,duration_minutes=duration,status='agendada',confirmed_at=null,version=version+1,updated_at=now() where id=item.id returning * into item;
  action_name:='appointment.rescheduled';
 end if;
 insert into app.patient_doctors(clinic_id,patient_id,membership_id) values(target_clinic,patient,doctor) on conflict do nothing;
 return private.finish_agenda_operation(target_clinic,operation_id,fingerprint,action_name,jsonb_build_object('status','saved','id',item.id,'version',item.version),item.id,patient);
end $$;
create function private.change_appointment_status(target_clinic uuid,appointment uuid,next_status text,expected_version integer,own_only boolean,operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb; item app.appointments%rowtype; fingerprint text; prior jsonb; doctor uuid; action_name text;
begin
 permission:=private.patient_permissions(target_clinic);
 select membership_id into doctor from app.appointments where clinic_id=target_clinic and id=appointment;
 permission:=private.lock_agenda_writer(target_clinic,doctor,own_only,operation_id,false);
 if next_status is null or next_status not in('confirmada','concluida','cancelada','falta') or expected_version is null or expected_version<1 then raise exception using errcode='22023',message='Invalid appointment status'; end if;
 fingerprint:=encode(sha256(convert_to(jsonb_build_array('status',target_clinic,appointment,next_status,expected_version,own_only)::text,'UTF8')),'hex');
 prior:=private.agenda_replay(target_clinic,operation_id,fingerprint); if prior is not null then return prior; end if;
 select * into item from app.appointments where clinic_id=target_clinic and id=appointment for update;
 if item.version<>expected_version or item.status not in('agendada','confirmada') or (next_status='confirmada' and item.status<>'agendada') then return jsonb_build_object('status','conflict'); end if;
 if next_status in('concluida','falta') and item.ends_at>now() then return jsonb_build_object('status','too_early'); end if;
 update app.appointments set status=next_status,confirmed_at=case when next_status='confirmada' then now() else null end,version=version+1,updated_at=now() where id=item.id returning * into item;
 action_name:=case next_status when 'confirmada' then 'appointment.confirmed' when 'concluida' then 'appointment.completed' when 'cancelada' then 'appointment.cancelled' else 'appointment.no_show' end;
 return private.finish_agenda_operation(target_clinic,operation_id,fingerprint,action_name,jsonb_build_object('status','saved','id',item.id,'version',item.version),item.id,item.patient_id);
end $$;

create function api.agenda_permissions(clinic_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$ select private.patient_permissions($1); $$;
create function api.agenda_doctors(clinic_id uuid,own_only boolean) returns jsonb language sql stable security invoker set search_path='' as $$ select private.agenda_doctors($1,$2); $$;
create function api.list_agenda(clinic_id uuid,day date,doctor_id uuid,own_only boolean,page_number integer) returns jsonb language sql security invoker set search_path='' as $$ select private.list_agenda($1,$2,$3,$4,$5); $$;
create function api.get_appointment(clinic_id uuid,appointment_id uuid,own_only boolean) returns jsonb language sql security invoker set search_path='' as $$ select private.get_appointment($1,$2,$3); $$;
create function api.agenda_availability(clinic_id uuid,doctor_id uuid,own_only boolean) returns jsonb language sql stable security invoker set search_path='' as $$ select private.agenda_availability($1,$2,$3); $$;
create function api.patient_appointments(clinic_id uuid,patient_id uuid,own_only boolean) returns jsonb language sql security invoker set search_path='' as $$ select private.patient_appointments($1,$2,$3); $$;
create function api.change_availability(clinic_id uuid,doctor_id uuid,window_id uuid,weekday integer,start_time time,end_time time,expected_version integer,own_only boolean,operation_id uuid) returns jsonb
 language sql security invoker set search_path='' as $$ select private.change_availability($1,$2,$3,$4,$5,$6,$7,$8,$9); $$;
create function api.change_agenda_block(clinic_id uuid,doctor_id uuid,block_id uuid,start_local timestamp,end_local timestamp,expected_version integer,own_only boolean,operation_id uuid) returns jsonb
 language sql security invoker set search_path='' as $$ select private.change_agenda_block($1,$2,$3,$4,$5,$6,$7,$8); $$;
create function api.save_appointment(clinic_id uuid,doctor_id uuid,patient_id uuid,appointment_id uuid,start_local timestamp,duration_minutes integer,expected_version integer,replace_id uuid,replace_version integer,own_only boolean,operation_id uuid) returns jsonb
 language sql security invoker set search_path='' as $$ select private.save_appointment($1,$2,$3,$4,$5,$6,$7,$8,$9,$10,$11); $$;
create function api.change_appointment_status(clinic_id uuid,appointment_id uuid,next_status text,expected_version integer,own_only boolean,operation_id uuid) returns jsonb
 language sql security invoker set search_path='' as $$ select private.change_appointment_status($1,$2,$3,$4,$5,$6); $$;
create function api.set_my_consultation_duration(clinic_id uuid,duration_minutes integer,operation_id uuid) returns jsonb
 language sql security invoker set search_path='' as $$ select private.set_my_consultation_duration($1,$2,$3); $$;

-- Revoke every new helper; grant only checked entry points and their invoker wrappers.
do $privileges$
declare item record;
begin
 for item in select p.oid::regprocedure as signature,n.nspname,p.proname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
  where n.nspname in('private','api') and p.proname=any(array['project_agenda_occupancy','record_appointment_history','agenda_allowed','lock_agenda_writer','agenda_replay','finish_agenda_operation','agenda_instant','appointment_json',
  'agenda_permissions','agenda_doctors','list_agenda','get_appointment','agenda_availability','patient_appointments','change_availability','change_agenda_block','save_appointment','change_appointment_status','set_my_consultation_duration'])
 loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',item.signature);
  if item.proname=any(array['agenda_permissions','agenda_doctors','list_agenda','get_appointment','agenda_availability','patient_appointments','change_availability','change_agenda_block','save_appointment','change_appointment_status','set_my_consultation_duration']) then
   execute format('grant execute on function %s to authenticated',item.signature);
  end if;
 end loop;
end $privileges$;
comment on table private.agenda_occupancy is 'Global physician/time exclusion including blocks. No client grants; no patient or clinic details.';
comment on table app.appointments is 'Official internal agenda. Clinic-local composite references; immutable history and versioned guarded mutations.';
