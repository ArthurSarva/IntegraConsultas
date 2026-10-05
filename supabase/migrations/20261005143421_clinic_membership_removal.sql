alter table app.memberships add column access_version integer not null default 1 check(access_version>0);
create function private.membership_access_version() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 new.access_version:=old.access_version+case when new.active is distinct from old.active then 1 else 0 end;
 return new;
end $$;
create trigger membership_access_version before update on app.memberships for each row execute function private.membership_access_version();
revoke all on function private.membership_access_version() from public,anon,authenticated,service_role;
alter table audit.events drop constraint events_action_check;
alter table audit.events add constraint events_action_check check(action in
 ('clinic.selected','clinic.created','administrator.linked','administrator.invitation_cancelled','team.linked','administrator.doctor_configured',
 'patient.created','patient.updated','patient.viewed','patient.searched','patient.deleted','patient.archived','administrator.removed','team.removed'));

create function private.require_membership_removal_manager(target_clinic uuid,member_kind text) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare actor uuid;
begin
 if member_kind='administrator' then
  perform private.require_dev_clinic(target_clinic); actor:=private.require_dev();
 elsif member_kind='team' then
  actor:=private.require_team_manager(target_clinic);
  if exists(select 1 from app.users where id=actor and is_dev) or not private.is_clinic_administrator(target_clinic) then
   raise exception using errcode='42501',message='Access denied'; end if;
 else raise exception using errcode='22023',message='Invalid membership kind'; end if;
 return actor;
end $$;
create function private.list_removable_members(target_clinic uuid,member_kind text) returns table(user_id uuid,access_version integer)
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.require_membership_removal_manager(target_clinic,member_kind);
begin
 return query select m.user_id,m.access_version from app.memberships m join app.users u on u.id=m.user_id
 where m.clinic_id=target_clinic and m.active and u.active and not u.is_dev and m.user_id<>actor
 and case when member_kind='administrator' then
  exists(select 1 from app.membership_roles r where r.clinic_id=m.clinic_id and r.membership_id=m.id and r.role='administrator')
 else
  exists(select 1 from app.membership_roles r where r.clinic_id=m.clinic_id and r.membership_id=m.id and r.role in('doctor','reception'))
  and not exists(select 1 from app.membership_roles r where r.clinic_id=m.clinic_id and r.membership_id=m.id and r.role='administrator')
 end;
end $$;
create function private.remove_clinic_member(target_clinic uuid,target_user uuid,member_kind text,expected_version integer,operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_membership_removal_manager(target_clinic,member_kind); member app.memberships%rowtype;
 prior audit.events%rowtype; manager_member uuid; action_name text:=case when member_kind='administrator' then 'administrator.removed' else 'team.removed' end;
 fingerprint text:=encode(sha256(convert_to(jsonb_build_array(operation_id,actor,target_clinic,target_user,member_kind,expected_version)::text,'UTF8')),'hex');
begin
 if target_user is null or operation_id is null or expected_version is null or expected_version<1 then raise exception using errcode='22023',message='Invalid removal input'; end if;
 if target_user=actor then return jsonb_build_object('status','self'); end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(operation_id::text,0));
 perform 1 from app.users where id=actor and active for update;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 select id into manager_member from app.memberships where clinic_id=target_clinic and user_id=actor and active for update;
 perform 1 from app.membership_roles where clinic_id=target_clinic and membership_id=manager_member for share;
 perform private.require_membership_removal_manager(target_clinic,member_kind);
 select * into member from app.memberships where clinic_id=target_clinic and user_id=target_user for update;
 if not found or exists(select 1 from app.users where id=target_user and is_dev) then raise exception using errcode='42501',message='Access denied'; end if;
 perform 1 from app.membership_roles where clinic_id=target_clinic and membership_id=member.id for share;
 if (member_kind='administrator' and not exists(select 1 from app.membership_roles where clinic_id=target_clinic and membership_id=member.id and role='administrator'))
  or (member_kind='team' and (exists(select 1 from app.membership_roles where clinic_id=target_clinic and membership_id=member.id and role='administrator')
   or not exists(select 1 from app.membership_roles where clinic_id=target_clinic and membership_id=member.id and role in('doctor','reception')))) then
  raise exception using errcode='42501',message='Access denied'; end if;
 select * into prior from audit.events where request_id=operation_id;
 if found then
  if prior.actor_user_id<>actor or prior.clinic_id<>target_clinic or prior.target_user_id<>target_user or prior.action<>action_name or prior.request_fingerprint<>fingerprint then
   raise exception using errcode='42501',message='Access denied'; end if;
  -- A replay must never revoke a subsequently restored membership.
  if member.active or member.access_version<>expected_version+1 then return jsonb_build_object('status','conflict'); end if;
  return jsonb_build_object('status','removed');
 end if;
 if not member.active or member.access_version<>expected_version then return jsonb_build_object('status','conflict'); end if;
 update app.memberships set active=false where id=member.id;
 insert into audit.events(clinic_id,actor_user_id,target_user_id,action,request_id,request_fingerprint)
 values(target_clinic,actor,target_user,action_name,operation_id,fingerprint);
 return jsonb_build_object('status','removed');
end $$;
create function api.list_removable_members(clinic_id uuid,member_kind text) returns table(user_id uuid,access_version integer)
language sql stable security invoker set search_path='' as $$ select * from private.list_removable_members(clinic_id,member_kind); $$;
create function api.remove_clinic_member(clinic_id uuid,user_id uuid,member_kind text,expected_version integer,operation_id uuid) returns jsonb
language sql security invoker set search_path='' as $$ select private.remove_clinic_member(clinic_id,user_id,member_kind,expected_version,operation_id); $$;
revoke all on function private.require_membership_removal_manager(uuid,text),private.list_removable_members(uuid,text),
 private.remove_clinic_member(uuid,uuid,text,integer,uuid),api.list_removable_members(uuid,text),api.remove_clinic_member(uuid,uuid,text,integer,uuid)
 from public,anon,authenticated,service_role;
grant execute on function private.require_membership_removal_manager(uuid,text),private.list_removable_members(uuid,text),
 private.remove_clinic_member(uuid,uuid,text,integer,uuid),api.list_removable_members(uuid,text),api.remove_clinic_member(uuid,uuid,text,integer,uuid) to authenticated;
