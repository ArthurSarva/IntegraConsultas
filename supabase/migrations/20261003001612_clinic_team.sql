-- Clinic administrator and Dev with MFA manage only the selected clinic's team.
create table app.doctor_settings (
 clinic_id uuid not null,
 membership_id uuid not null,
 default_duration_minutes integer not null default 30 check(default_duration_minutes in (15,30,45,60)),
 primary key(clinic_id,membership_id),
 foreign key(clinic_id,membership_id) references app.memberships(clinic_id,id) on delete restrict
);
alter table app.doctor_settings enable row level security;
revoke all on app.doctor_settings from public,anon,authenticated,service_role;
grant select on app.doctor_settings to authenticated;
create policy doctor_settings_read on app.doctor_settings for select to authenticated
 using(clinic_id=(select private.current_clinic_id()) and
  (private.is_clinic_administrator(clinic_id) or private.is_own_membership(clinic_id,membership_id)));
alter table audit.events drop constraint events_action_check;
alter table audit.events add constraint events_action_check
 check(action in ('clinic.selected','clinic.created','administrator.linked','administrator.invitation_cancelled','team.linked'));

create function private.require_team_manager(target_clinic uuid) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.active_user_id();
begin
 if actor is null or auth.jwt()->>'aal' is distinct from 'aal2'
  or target_clinic is null or private.current_clinic_id() is distinct from target_clinic
  or not (private.is_clinic_administrator(target_clinic) or
   exists(select 1 from app.users u where u.id=actor and u.is_dev)) then
  raise exception using errcode='42501',message='Access denied';
 end if;
 return actor;
end $$;
create function private.team_candidate(target_clinic uuid,target_email text) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare person auth.users%rowtype;
begin
 perform private.require_team_manager(target_clinic);
 select * into person from auth.users u where lower(u.email)=lower(btrim(target_email)) and u.deleted_at is null;
 if not found then return null; end if;
 if (person.banned_until is not null and person.banned_until>now())
  or exists(select 1 from app.users u where u.id=person.id and (not u.active or u.is_dev)) then
  raise exception using errcode='42501',message='Access denied';
 end if;
 return jsonb_build_object('id',person.id,'confirmed',person.email_confirmed_at is not null);
end $$;
create function private.link_team_member(target_clinic uuid,target_user uuid,target_email text,person_name text,
 target_role text,with_reception boolean,duration_minutes integer,operation_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_team_manager(target_clinic); member app.memberships%rowtype; prior audit.events%rowtype;
 fingerprint text:=md5(jsonb_build_array(target_clinic,target_user,lower(btrim(target_email)),btrim(person_name),target_role,with_reception,duration_minutes)::text);
begin
 if operation_id is null or person_name is null or length(btrim(person_name)) not between 1 and 120
  or target_role is null or target_role not in ('doctor','reception') or with_reception is null
  or (target_role='doctor' and (duration_minutes is null or duration_minutes not in (15,30,45,60)))
  or (target_role='reception' and (with_reception or duration_minutes is not null)) then
  raise exception using errcode='22023',message='Invalid team input';
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(operation_id::text,0));
 select * into prior from audit.events where request_id=operation_id;
 if found then
  if prior.actor_user_id<>actor or prior.action<>'team.linked' or prior.request_fingerprint<>fingerprint then
   raise exception using errcode='42501',message='Access denied';
  end if;
  return prior.target_user_id;
 end if;
 if not exists(select 1 from auth.users u where u.id=target_user and lower(u.email)=lower(btrim(target_email))
  and u.deleted_at is null and (u.banned_until is null or u.banned_until<=now())) then
  raise exception using errcode='42501',message='Access denied';
 end if;
 insert into app.users(id,display_name) values(target_user,btrim(person_name)) on conflict(id) do nothing;
 perform 1 from app.users where id=target_user and active and not is_dev for update;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 insert into app.memberships(clinic_id,user_id) values(target_clinic,target_user) on conflict(clinic_id,user_id) do nothing;
 select * into member from app.memberships where clinic_id=target_clinic and user_id=target_user for update;
 if not member.active then raise exception using errcode='42501',message='Access denied'; end if;
 insert into app.membership_roles(clinic_id,membership_id,role,scope)
  values(target_clinic,member.id,target_role,case when target_role='doctor' then 'own' else 'clinic' end)
  on conflict(clinic_id,membership_id,role) do nothing;
 if target_role='doctor' then
  insert into app.doctor_settings(clinic_id,membership_id,default_duration_minutes) values(target_clinic,member.id,duration_minutes)
   on conflict(clinic_id,membership_id) do update set default_duration_minutes=excluded.default_duration_minutes;
  if with_reception then
   insert into app.membership_roles(clinic_id,membership_id,role,scope) values(target_clinic,member.id,'reception','own')
    on conflict(clinic_id,membership_id,role) do nothing;
  end if;
 end if;
 -- Adding reception to an existing doctor must also stay within the doctor's own agenda.
 if exists(select 1 from app.membership_roles where clinic_id=target_clinic and membership_id=member.id and role='doctor') then
  update app.membership_roles set scope='own' where clinic_id=target_clinic and membership_id=member.id and role='reception';
 end if;
 insert into audit.events(clinic_id,actor_user_id,target_user_id,action,request_id,request_fingerprint)
  values(target_clinic,actor,target_user,'team.linked',operation_id,fingerprint);
 return target_user;
end $$;
create function private.list_team() returns table(id uuid,display_name text,email text,active boolean,confirmed boolean,roles jsonb,duration_minutes integer)
language plpgsql stable security definer set search_path='' as $$
declare target uuid:=private.current_clinic_id();
begin
 perform private.require_team_manager(target);
 return query select u.id,u.display_name,a.email::text,u.active and m.active,a.email_confirmed_at is not null,
  jsonb_agg(jsonb_build_object('role',r.role,'scope',r.scope) order by r.role),d.default_duration_minutes
 from app.memberships m join app.users u on u.id=m.user_id join auth.users a on a.id=u.id
 join app.membership_roles r on r.clinic_id=m.clinic_id and r.membership_id=m.id and r.role in ('doctor','reception')
 left join app.doctor_settings d on d.clinic_id=m.clinic_id and d.membership_id=m.id
 where m.clinic_id=target group by u.id,a.email,a.email_confirmed_at,m.active,d.default_duration_minutes
 order by u.display_name,u.id;
end $$;
create function api.team_clinic_context(clinic_id uuid) returns uuid
language plpgsql stable security invoker set search_path='' as $$ begin perform private.require_team_manager(clinic_id); return clinic_id; end $$;
create function api.team_candidate(clinic_id uuid,email text) returns jsonb
language sql stable security invoker set search_path='' as $$ select private.team_candidate(clinic_id,email); $$;
create function api.link_team_member(clinic_id uuid,user_id uuid,email text,display_name text,team_role text,with_reception boolean,duration_minutes integer,operation_id uuid) returns uuid
language sql security invoker set search_path='' as $$ select private.link_team_member(clinic_id,user_id,email,display_name,team_role,with_reception,duration_minutes,operation_id); $$;
create function api.list_team() returns table(id uuid,display_name text,email text,active boolean,confirmed boolean,roles jsonb,duration_minutes integer)
language sql stable security invoker set search_path='' as $$ select * from private.list_team(); $$;
revoke all on function private.require_team_manager(uuid),private.team_candidate(uuid,text),
 private.link_team_member(uuid,uuid,text,text,text,boolean,integer,uuid),private.list_team(),api.team_clinic_context(uuid),api.team_candidate(uuid,text),
 api.link_team_member(uuid,uuid,text,text,text,boolean,integer,uuid),api.list_team() from public,anon,authenticated,service_role;
grant execute on function private.require_team_manager(uuid),private.team_candidate(uuid,text),
 private.link_team_member(uuid,uuid,text,text,text,boolean,integer,uuid),private.list_team(),api.team_clinic_context(uuid),api.team_candidate(uuid,text),
 api.link_team_member(uuid,uuid,text,text,text,boolean,integer,uuid),api.list_team() to authenticated;
comment on table app.doctor_settings is 'Default consultation duration per doctor membership. Appointment-specific exceptions belong to scheduling.';
