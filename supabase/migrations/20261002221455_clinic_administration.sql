-- Dev-only clinic creation and administrator provisioning. No direct table writes.
alter table audit.events drop constraint events_action_check;
alter table audit.events add constraint events_action_check
 check (action in ('clinic.selected','clinic.created','administrator.linked'));
alter table audit.events add column target_user_id uuid references app.users(id) on delete restrict;
alter table audit.events add column request_id uuid unique;
alter table audit.events add column request_fingerprint text;
alter table audit.events add constraint events_request_check check (
 (request_id is null and request_fingerprint is null) or
 (request_id is not null and length(request_fingerprint)=32));
create index audit_events_target_idx on audit.events(target_user_id) where target_user_id is not null;

create function private.require_dev() returns uuid
language plpgsql stable security definer set search_path=''
as $$
declare actor uuid:=private.active_user_id();
begin
 if actor is null or auth.jwt()->>'aal' is distinct from 'aal2'
   or not exists(select 1 from app.users u where u.id=actor and u.is_dev) then
  raise exception using errcode='42501',message='Access denied';
 end if;
 return actor;
end;
$$;
create function private.require_dev_clinic(target uuid) returns uuid
language plpgsql stable security definer set search_path=''
as $$
begin
 perform private.require_dev();
 if target is null or private.current_clinic_id() is distinct from target then
  raise exception using errcode='42501',message='Access denied';
 end if;
 return target;
end;
$$;
create function private.create_clinic(clinic_name text,clinic_timezone text,operation_id uuid) returns uuid
language plpgsql security definer set search_path=''
as $$
declare actor uuid:=private.require_dev(); result uuid; prior audit.events%rowtype;
 fingerprint text:=pg_catalog.md5(pg_catalog.jsonb_build_array(btrim(clinic_name),clinic_timezone)::text);
begin
 if operation_id is null then raise exception using errcode='22023',message='Operation required'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(operation_id::text,0));
 select * into prior from audit.events e where e.request_id=operation_id;
 if found then
  if prior.actor_user_id<>actor or prior.action<>'clinic.created' or prior.request_fingerprint<>fingerprint
     or not private.can_enter_clinic(prior.clinic_id) then
   raise exception using errcode='42501',message='Access denied';
  end if;
  return prior.clinic_id;
 end if;
 insert into app.clinics(name,timezone) values(btrim(clinic_name),clinic_timezone) returning id into result;
 insert into audit.events(clinic_id,actor_user_id,action,request_id,request_fingerprint)
  values(result,actor,'clinic.created',operation_id,fingerprint);
 return result;
end;
$$;
create function private.administrator_candidate(target_clinic uuid,target_email text) returns jsonb
language plpgsql stable security definer set search_path=''
as $$
declare result auth.users%rowtype;
begin
 perform private.require_dev_clinic(target_clinic);
 select * into result from auth.users u where lower(u.email)=lower(btrim(target_email)) and u.deleted_at is null;
 if not found then return null; end if;
 if (result.banned_until is not null and result.banned_until>now())
    or exists(select 1 from app.users p where p.id=result.id and not p.active) then
  raise exception using errcode='42501',message='Access denied';
 end if;
 return pg_catalog.jsonb_build_object('id',result.id,'confirmed',result.email_confirmed_at is not null);
end;
$$;
create function private.link_administrator(target_clinic uuid,target_user uuid,target_email text,person_name text,operation_id uuid) returns uuid
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
 insert into audit.events(clinic_id,actor_user_id,target_user_id,action,request_id,request_fingerprint)
  values(target_clinic,actor,target_user,'administrator.linked',operation_id,fingerprint);
 return target_user;
end;
$$;
create function private.list_administrators() returns table(id uuid,display_name text,email text,active boolean,confirmed boolean)
language plpgsql stable security definer set search_path=''
as $$
declare target uuid:=private.current_clinic_id();
begin
 perform private.require_dev_clinic(target);
 return query select p.id,p.display_name,u.email::text,p.active and m.active,u.email_confirmed_at is not null
  from app.memberships m join app.membership_roles r on r.clinic_id=m.clinic_id and r.membership_id=m.id
  join app.users p on p.id=m.user_id join auth.users u on u.id=p.id
  where m.clinic_id=target and r.role='administrator' order by p.display_name,p.id;
end;
$$;
create function api.create_clinic(clinic_name text,clinic_timezone text,operation_id uuid) returns uuid
 language sql security invoker set search_path='' as $$ select private.create_clinic(clinic_name,clinic_timezone,operation_id); $$;
create function api.dev_clinic_context(clinic_id uuid) returns uuid
 language sql stable security invoker set search_path='' as $$ select private.require_dev_clinic(clinic_id); $$;
create function api.administrator_candidate(clinic_id uuid,email text) returns jsonb
 language sql stable security invoker set search_path='' as $$ select private.administrator_candidate(clinic_id,email); $$;
create function api.link_administrator(clinic_id uuid,user_id uuid,email text,display_name text,operation_id uuid) returns uuid
 language sql security invoker set search_path='' as $$ select private.link_administrator(clinic_id,user_id,email,display_name,operation_id); $$;
create function api.list_administrators() returns table(id uuid,display_name text,email text,active boolean,confirmed boolean)
 language sql stable security invoker set search_path='' as $$ select * from private.list_administrators(); $$;
revoke all on function private.require_dev(),private.require_dev_clinic(uuid),
 private.create_clinic(text,text,uuid),private.administrator_candidate(uuid,text),
 private.link_administrator(uuid,uuid,text,text,uuid),private.list_administrators(),
 api.create_clinic(text,text,uuid),api.dev_clinic_context(uuid),
 api.administrator_candidate(uuid,text),api.link_administrator(uuid,uuid,text,text,uuid),api.list_administrators()
 from public,anon,authenticated,service_role;
grant execute on function private.require_dev(),private.require_dev_clinic(uuid),
 private.create_clinic(text,text,uuid),private.administrator_candidate(uuid,text),
 private.link_administrator(uuid,uuid,text,text,uuid),private.list_administrators(),
 api.create_clinic(text,text,uuid),api.dev_clinic_context(uuid),
 api.administrator_candidate(uuid,text),api.link_administrator(uuid,uuid,text,text,uuid),api.list_administrators()
 to authenticated;
comment on function private.require_dev() is 'Verified active session, DB-backed Dev flag and aal2; no caller-supplied actor.';
comment on column audit.events.request_id is 'Idempotency key; repeats require same actor, action and payload fingerprint.';
comment on column audit.events.target_user_id is 'Affected identity only; invitation tokens and passwords must never enter audit.';
