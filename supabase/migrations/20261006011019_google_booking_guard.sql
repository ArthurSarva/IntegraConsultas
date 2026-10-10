-- Connected calendars require a server-checked preflight even for direct API calls.
create table private.google_booking_checks(
 clinic_id uuid not null references app.clinics(id),user_id uuid not null references app.users(id),session_id uuid not null references auth.sessions(id) on delete cascade,
 operation_id uuid not null,proof uuid not null default gen_random_uuid() unique,doctor_id uuid not null,start_local timestamp not null,duration integer not null,
 connected_at timestamptz not null,outcome text check(outcome in('free','unavailable','busy')),expires_at timestamptz not null default now()+interval '90 seconds',
 primary key(clinic_id,user_id,operation_id),foreign key(clinic_id,doctor_id) references app.memberships(clinic_id,id)
);
alter table private.google_booking_checks enable row level security;
create policy booking_checks_private on private.google_booking_checks for all using(false) with check(false);
revoke all on private.google_booking_checks from public,anon,authenticated,service_role;
create function private.google_begin_booking(target_clinic uuid,doctor uuid,local_start timestamp,duration integer,own_only boolean,operation uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare result jsonb; epoch timestamptz; nonce uuid;
begin
 result:=private.google_booking_window(target_clinic,doctor,local_start,duration,own_only);
 if operation is null then raise exception using errcode='22023',message='Invalid operation'; end if;
 select connected_at into epoch from private.google_connections where clinic_id=target_clinic and membership_id=doctor;
 if epoch is null then return result; end if;
 delete from private.google_booking_checks where expires_at<now();
 insert into private.google_booking_checks(clinic_id,user_id,session_id,operation_id,doctor_id,start_local,duration,connected_at)
 values(target_clinic,private.active_user_id(),private.request_session_id(),operation,doctor,local_start,duration,epoch)
 on conflict(clinic_id,user_id,operation_id) do update set session_id=excluded.session_id,doctor_id=excluded.doctor_id,start_local=excluded.start_local,duration=excluded.duration,connected_at=excluded.connected_at,
 proof=gen_random_uuid(),outcome=null,expires_at=now()+interval '90 seconds' returning proof into nonce;
 return result||jsonb_build_object('proof',nonce);
end $$;
create function api.google_begin_booking(clinic_id uuid,doctor_id uuid,start_local timestamp,duration_minutes integer,own_only boolean,operation_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.google_begin_booking($1,$2,$3,$4,$5,$6); $$;
create function private.google_approve_booking(target_clinic uuid,nonce uuid,result text) returns boolean
language plpgsql security definer set search_path='' as $$
begin
 if current_setting('role',true)<>'service_role' then raise exception using errcode='42501',message='Technical worker required'; end if;
 if result is null or result not in('free','unavailable','busy') then raise exception using errcode='22023',message='Invalid result'; end if;
 update private.google_booking_checks set outcome=result where clinic_id=target_clinic and proof=nonce and expires_at>now() and outcome is null;
 return found;
end $$;
create function api.google_approve_booking(clinic_id uuid,proof uuid,outcome text) returns boolean language sql security invoker set search_path='' as $$ select private.google_approve_booking($1,$2,$3); $$;
alter function private.save_appointment(uuid,uuid,uuid,uuid,timestamp,integer,integer,uuid,integer,boolean,uuid) rename to save_appointment_internal;
revoke all on function private.save_appointment_internal(uuid,uuid,uuid,uuid,timestamp,integer,integer,uuid,integer,boolean,uuid) from public,anon,authenticated,service_role;
create function private.save_appointment(target_clinic uuid,doctor uuid,patient uuid,appointment uuid,start_local timestamp,duration integer,expected_version integer,replace_id uuid,replace_version integer,own_only boolean,operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare p jsonb:=private.patient_permissions(target_clinic); epoch timestamptz;
begin
 if not coalesce((p->>'can_write')::boolean,false) or not private.agenda_allowed(p,doctor,own_only) then raise exception using errcode='42501',message='Access denied'; end if;
 select connected_at into epoch from private.google_connections where clinic_id=target_clinic and membership_id=doctor;
 if epoch is not null and not exists(select 1 from private.google_booking_checks x where x.clinic_id=target_clinic and x.user_id=private.active_user_id() and x.session_id=private.request_session_id()
 and x.operation_id=save_appointment.operation_id and x.doctor_id=doctor and x.start_local=save_appointment.start_local and x.duration=save_appointment.duration and x.connected_at=epoch and x.expires_at>now() and x.outcome in('free','unavailable')) then
 return jsonb_build_object('status','google_check_required'); end if;
 return private.save_appointment_internal(target_clinic,doctor,patient,appointment,start_local,duration,expected_version,replace_id,replace_version,own_only,operation_id);
end $$;
revoke all on function private.save_appointment(uuid,uuid,uuid,uuid,timestamp,integer,integer,uuid,integer,boolean,uuid),private.google_begin_booking(uuid,uuid,timestamp,integer,boolean,uuid),api.google_begin_booking(uuid,uuid,timestamp,integer,boolean,uuid),private.google_approve_booking(uuid,uuid,text),api.google_approve_booking(uuid,uuid,text) from public,anon,authenticated,service_role;
grant execute on function private.save_appointment(uuid,uuid,uuid,uuid,timestamp,integer,integer,uuid,integer,boolean,uuid),private.google_begin_booking(uuid,uuid,timestamp,integer,boolean,uuid),api.google_begin_booking(uuid,uuid,timestamp,integer,boolean,uuid) to authenticated;
grant execute on function private.google_approve_booking(uuid,uuid,text),api.google_approve_booking(uuid,uuid,text) to service_role;
