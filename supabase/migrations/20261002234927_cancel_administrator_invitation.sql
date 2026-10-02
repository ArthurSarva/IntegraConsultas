-- Cancellation is scoped to the selected clinic; original invite secrets are never stored.
create table private.cancelled_administrator_invitations (
 clinic_id uuid not null references app.clinics(id) on delete restrict,
 user_id uuid not null references app.users(id) on delete restrict,
 cancelled_at timestamptz not null default now(),
 invalidated boolean not null default false,
 token_fingerprint text,
 primary key(clinic_id,user_id));
create index cancelled_invitations_user_idx on private.cancelled_administrator_invitations(user_id);
alter table private.cancelled_administrator_invitations enable row level security;
revoke all on private.cancelled_administrator_invitations from public,anon,authenticated,service_role;
alter table audit.events drop constraint events_action_check;
alter table audit.events add constraint events_action_check
 check(action in ('clinic.selected','clinic.created','administrator.linked','administrator.invitation_cancelled'));

create function private.cancel_administrator_invitation(target_clinic uuid,target_user uuid,operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.require_dev(); person auth.users%rowtype; member app.memberships%rowtype;
 prior audit.events%rowtype; fingerprint text:=md5(jsonb_build_array(target_clinic,target_user)::text);
begin
 perform private.require_dev_clinic(target_clinic);
 if operation_id is null then raise exception using errcode='22023',message='Operation required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(operation_id::text,0));
 select * into prior from audit.events where request_id=operation_id;
 if found and (prior.actor_user_id<>actor or prior.action<>'administrator.invitation_cancelled' or prior.request_fingerprint<>fingerprint) then
  raise exception using errcode='42501',message='Access denied';
 end if;
 if prior.id is not null and not exists(select 1 from private.cancelled_administrator_invitations where clinic_id=target_clinic and user_id=target_user) then
  raise exception using errcode='42501',message='New operation required';
 end if;
 select * into person from auth.users where id=target_user and deleted_at is null for update;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 if exists(select 1 from private.cancelled_administrator_invitations where clinic_id=target_clinic and user_id=target_user) then
  return jsonb_build_object('email',person.email,'confirmed',person.email_confirmed_at is not null,'invalidated',(select invalidated from private.cancelled_administrator_invitations where clinic_id=target_clinic and user_id=target_user));
 end if;
 if person.email_confirmed_at is not null then raise exception using errcode='22023',message='Invitation already accepted'; end if;
 select * into member from app.memberships where clinic_id=target_clinic and user_id=target_user for update;
 if not found or not exists(select 1 from app.membership_roles where clinic_id=target_clinic and membership_id=member.id and role='administrator') then
  raise exception using errcode='42501',message='Access denied';
 end if;
 delete from app.membership_roles where clinic_id=target_clinic and membership_id=member.id and role='administrator';
 insert into private.cancelled_administrator_invitations(clinic_id,user_id,token_fingerprint) values(target_clinic,target_user,encode(sha256(convert_to(coalesce(person.confirmation_token,''),'UTF8')),'hex'));
 insert into audit.events(clinic_id,actor_user_id,target_user_id,action,request_id,request_fingerprint)
  values(target_clinic,actor,target_user,'administrator.invitation_cancelled',operation_id,fingerprint);
 return jsonb_build_object('email',person.email,'confirmed',false);
end $$;
create function api.cancel_administrator_invitation(clinic_id uuid,user_id uuid,operation_id uuid) returns jsonb
language sql security invoker set search_path='' as $$ select private.cancel_administrator_invitation(clinic_id,user_id,operation_id); $$;

create function private.complete_invitation_cancellation(target_clinic uuid,target_user uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform private.require_dev_clinic(target_clinic);
 if exists(select 1 from private.cancelled_administrator_invitations c join auth.users u on u.id=c.user_id
  where c.clinic_id=target_clinic and c.user_id=target_user and u.email_confirmed_at is null
  and c.token_fingerprint=encode(sha256(convert_to(coalesce(u.confirmation_token,''),'UTF8')),'hex')) then
  raise exception using errcode='22023',message='Auth invalidation pending';
 end if;
 update private.cancelled_administrator_invitations set invalidated=true where clinic_id=target_clinic and user_id=target_user;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
end $$;
create function api.complete_invitation_cancellation(clinic_id uuid,user_id uuid) returns void
language sql security invoker set search_path='' as $$ select private.complete_invitation_cancellation(clinic_id,user_id); $$;
revoke all on function private.cancel_administrator_invitation(uuid,uuid,uuid),api.cancel_administrator_invitation(uuid,uuid,uuid),private.complete_invitation_cancellation(uuid,uuid),api.complete_invitation_cancellation(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function private.cancel_administrator_invitation(uuid,uuid,uuid),api.cancel_administrator_invitation(uuid,uuid,uuid),private.complete_invitation_cancellation(uuid,uuid),api.complete_invitation_cancellation(uuid,uuid) to authenticated;

drop function api.list_administrators();
drop function private.list_administrators();
create function private.list_administrators() returns table(id uuid,display_name text,email text,active boolean,confirmed boolean,cancelled boolean,invalidation_pending boolean)
language plpgsql stable security definer set search_path='' as $$
declare target uuid:=private.current_clinic_id();
begin
 perform private.require_dev_clinic(target);
 return query select p.id,p.display_name,u.email::text,p.active and m.active,u.email_confirmed_at is not null,c.user_id is not null,coalesce(not c.invalidated,false)
 from app.memberships m join app.users p on p.id=m.user_id join auth.users u on u.id=p.id
 left join app.membership_roles r on r.clinic_id=m.clinic_id and r.membership_id=m.id and r.role='administrator'
 left join private.cancelled_administrator_invitations c on c.clinic_id=m.clinic_id and c.user_id=m.user_id
 where m.clinic_id=target and (r.membership_id is not null or c.user_id is not null) order by p.display_name,p.id;
end $$;
create function api.list_administrators() returns table(id uuid,display_name text,email text,active boolean,confirmed boolean,cancelled boolean,invalidation_pending boolean)
language sql stable security invoker set search_path='' as $$ select * from private.list_administrators(); $$;
revoke all on function private.list_administrators(),api.list_administrators() from public,anon,authenticated,service_role;
grant execute on function private.list_administrators(),api.list_administrators() to authenticated;

create or replace function private.link_administrator(target_clinic uuid,target_user uuid,target_email text,person_name text,operation_id uuid) returns uuid
language plpgsql security definer set search_path=''
as $$
declare actor uuid:=private.require_dev(); member app.memberships%rowtype;
 prior audit.events%rowtype; fingerprint text:=pg_catalog.md5(pg_catalog.jsonb_build_array(target_clinic,target_user,lower(btrim(target_email)),btrim(person_name))::text);
begin
 perform private.require_dev_clinic(target_clinic);
 if operation_id is null or person_name is null or length(btrim(person_name)) not between 1 and 120 then
  raise exception using errcode='22023',message='Invalid input';
 end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(operation_id::text,0));
 select * into prior from audit.events e where e.request_id=operation_id;
 if found then
  if prior.actor_user_id<>actor or prior.action<>'administrator.linked' or prior.request_fingerprint<>fingerprint then
   raise exception using errcode='42501',message='Access denied';
  end if;
  if exists(select 1 from private.cancelled_administrator_invitations where clinic_id=target_clinic and user_id=target_user) then
   raise exception using errcode='42501',message='New operation required';
  end if;
  return prior.target_user_id;
 end if;
 if not exists(select 1 from auth.users u where u.id=target_user
   and lower(u.email)=lower(btrim(target_email)) and u.deleted_at is null
   and (u.banned_until is null or u.banned_until<=now())) then
  raise exception using errcode='42501',message='Access denied';
 end if;
 insert into app.users(id,display_name) values(target_user,btrim(person_name)) on conflict(id) do nothing;
 perform 1 from app.users u where u.id=target_user and u.active for update;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 insert into app.memberships(clinic_id,user_id) values(target_clinic,target_user)
  on conflict(clinic_id,user_id) do nothing;
 select * into member from app.memberships m where m.clinic_id=target_clinic and m.user_id=target_user for update;
 if not member.active then raise exception using errcode='42501',message='Access denied'; end if;
 insert into app.membership_roles(clinic_id,membership_id,role,scope)
  values(target_clinic,member.id,'administrator','clinic') on conflict do nothing;
 delete from private.cancelled_administrator_invitations where clinic_id=target_clinic and user_id=target_user;
 insert into audit.events(clinic_id,actor_user_id,target_user_id,action,request_id,request_fingerprint)
  values(target_clinic,actor,target_user,'administrator.linked',operation_id,fingerprint);
 return target_user;
end;
$$;
