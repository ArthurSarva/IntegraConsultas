-- Self-enrollment adds doctor capabilities without touching Auth or administration.
alter table audit.events drop constraint events_action_check;
alter table audit.events add constraint events_action_check check(action in
 ('clinic.selected','clinic.created','administrator.linked','administrator.invitation_cancelled','team.linked','administrator.doctor_configured'));

create function private.configure_administrator_doctor(target_clinic uuid,duration_minutes integer,operation_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_team_manager(target_clinic); member app.memberships%rowtype; prior audit.events%rowtype;
 fingerprint text:=md5(jsonb_build_array('administrator.doctor_configured',target_clinic,actor,duration_minutes)::text);
begin
 if operation_id is null or duration_minutes is null or duration_minutes not in (15,30,45,60) then
  raise exception using errcode='22023',message='Invalid doctor input';
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(operation_id::text,0));
 perform 1 from app.users where id=actor and active and not is_dev for update;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 select * into member from app.memberships where clinic_id=target_clinic and user_id=actor for update;
 if not found or not member.active then raise exception using errcode='42501',message='Access denied'; end if;
 -- Check the live administrator role after acquiring the membership lock.
 perform 1 from app.membership_roles where clinic_id=target_clinic and membership_id=member.id and role='administrator' for share;
 if not found or private.active_user_id() is distinct from actor or auth.jwt()->>'aal' is distinct from 'aal2'
  or private.current_clinic_id() is distinct from target_clinic then
  raise exception using errcode='42501',message='Access denied';
 end if;
 select * into prior from audit.events where request_id=operation_id;
 if found then
  if prior.actor_user_id<>actor or prior.action<>'administrator.doctor_configured' or prior.request_fingerprint<>fingerprint then
   raise exception using errcode='42501',message='Access denied';
  end if;
  return actor;
 end if;
 insert into app.membership_roles(clinic_id,membership_id,role,scope) values(target_clinic,member.id,'doctor','own')
  on conflict(clinic_id,membership_id,role) do nothing;
 insert into app.doctor_settings(clinic_id,membership_id,default_duration_minutes) values(target_clinic,member.id,duration_minutes)
  on conflict(clinic_id,membership_id) do update set default_duration_minutes=excluded.default_duration_minutes;
 update app.membership_roles set scope='own' where clinic_id=target_clinic and membership_id=member.id and role='reception';
 insert into audit.events(clinic_id,actor_user_id,target_user_id,action,request_id,request_fingerprint)
  values(target_clinic,actor,actor,'administrator.doctor_configured',operation_id,fingerprint);
 return actor;
end $$;
create function api.configure_administrator_doctor(clinic_id uuid,duration_minutes integer,operation_id uuid) returns uuid
language sql security invoker set search_path='' as $$ select private.configure_administrator_doctor(clinic_id,duration_minutes,operation_id); $$;
revoke all on function private.configure_administrator_doctor(uuid,integer,uuid),api.configure_administrator_doctor(uuid,integer,uuid) from public,anon,authenticated,service_role;
grant execute on function private.configure_administrator_doctor(uuid,integer,uuid),api.configure_administrator_doctor(uuid,integer,uuid) to authenticated;
