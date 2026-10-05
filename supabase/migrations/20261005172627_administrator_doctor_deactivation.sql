-- Remove only the caller's doctor capability; retain clinic administration and history.
alter table audit.events drop constraint events_action_check;
alter table audit.events add constraint events_action_check check(action in
 ('clinic.selected','clinic.created','administrator.linked','administrator.invitation_cancelled','team.linked','administrator.doctor_configured',
 'patient.created','patient.updated','patient.viewed','patient.searched','patient.deleted','patient.archived','administrator.removed','team.removed',
 'administrator.doctor_disabled'));

create function private.disable_administrator_doctor(target_clinic uuid,operation_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_team_manager(target_clinic); member app.memberships%rowtype; prior audit.events%rowtype;
 fingerprint text:=md5(jsonb_build_array('administrator.doctor_disabled',target_clinic,actor)::text);
begin
 if operation_id is null then raise exception using errcode='22023',message='Invalid doctor input'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(operation_id::text,0));
 perform 1 from app.users where id=actor and active and not is_dev for update;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 select * into member from app.memberships where clinic_id=target_clinic and user_id=actor for update;
 if not found or not member.active then raise exception using errcode='42501',message='Access denied'; end if;
 perform 1 from app.membership_roles where clinic_id=target_clinic and membership_id=member.id and role='administrator' for share;
 if not found or private.active_user_id() is distinct from actor or auth.jwt()->>'aal' is distinct from 'aal2'
  or private.current_clinic_id() is distinct from target_clinic then
  raise exception using errcode='42501',message='Access denied';
 end if;
 select * into prior from audit.events where request_id=operation_id;
 if found then
  if prior.actor_user_id<>actor or prior.action<>'administrator.doctor_disabled' or prior.request_fingerprint<>fingerprint
   or exists(select 1 from app.membership_roles where clinic_id=target_clinic and membership_id=member.id and role='doctor') then
   raise exception using errcode='42501',message='Access denied';
  end if;
  return actor;
 end if;
 delete from app.membership_roles where clinic_id=target_clinic and membership_id=member.id and role='doctor';
 -- Keep doctor_settings, patient_doctors, reception scope and all other memberships.
 insert into audit.events(clinic_id,actor_user_id,target_user_id,action,request_id,request_fingerprint)
  values(target_clinic,actor,actor,'administrator.doctor_disabled',operation_id,fingerprint);
 return actor;
end $$;
create function api.disable_administrator_doctor(clinic_id uuid,operation_id uuid) returns uuid
language sql security invoker set search_path='' as $$ select private.disable_administrator_doctor(clinic_id,operation_id); $$;
revoke all on function private.disable_administrator_doctor(uuid,uuid),api.disable_administrator_doctor(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function private.disable_administrator_doctor(uuid,uuid),api.disable_administrator_doctor(uuid,uuid) to authenticated;
