-- Generated filename by Supabase CLI. Initial schema; no operational CRUD granted.
create schema app;
create schema private;
create schema api;
create schema audit;
revoke all on schema app, private, api, audit from public, anon, authenticated, service_role;
grant usage on schema app, private, api, audit to authenticated;
alter default privileges in schema app, private, api, audit revoke execute on functions from public;
alter default privileges in schema app, private, api, audit revoke all on tables from anon, authenticated, service_role;

create table app.users (
  id uuid primary key references auth.users(id) on delete restrict,
  display_name text not null check (length(btrim(display_name)) between 1 and 120),
  active boolean not null default true,
  is_dev boolean not null default false,
  created_at timestamptz not null default now()
);
create table app.clinics (
  id uuid primary key default gen_random_uuid(),
  name text not null check (length(btrim(name)) between 1 and 160),
  timezone text not null default 'America/Sao_Paulo',
  active boolean not null default true,
  created_at timestamptz not null default now()
);
create table app.memberships (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references app.clinics(id) on delete restrict,
  user_id uuid not null references app.users(id) on delete restrict,
  active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (clinic_id, user_id),
  unique (clinic_id, id)
);
create index memberships_user_idx on app.memberships(user_id, clinic_id);
create table app.membership_roles (
  clinic_id uuid not null,
  membership_id uuid not null,
  role text not null check (role in ('administrator', 'doctor', 'reception')),
  scope text not null check (scope in ('own', 'clinic')),
  primary key (clinic_id, membership_id, role),
  foreign key (clinic_id, membership_id) references app.memberships(clinic_id, id) on delete restrict,
  check ((role = 'administrator' and scope = 'clinic')
    or (role = 'doctor' and scope = 'own') or role = 'reception')
);
create table private.clinic_contexts (
  session_id uuid primary key references auth.sessions(id) on delete cascade,
  user_id uuid not null references app.users(id) on delete restrict,
  clinic_id uuid not null references app.clinics(id) on delete restrict,
  selected_at timestamptz not null default now()
);
create index clinic_contexts_user_idx on private.clinic_contexts(user_id);
create index clinic_contexts_clinic_idx on private.clinic_contexts(clinic_id);
create table audit.events (
  id uuid primary key default gen_random_uuid(),
  clinic_id uuid not null references app.clinics(id) on delete restrict,
  actor_user_id uuid not null references app.users(id) on delete restrict,
  action text not null check (action in ('clinic.selected')),
  occurred_at timestamptz not null default now()
);
create index audit_events_clinic_time_idx on audit.events(clinic_id, occurred_at desc);
create index audit_events_actor_idx on audit.events(actor_user_id);

-- Validate timezone at the DB boundary, including technical provisioning.
create function private.validate_clinic_timezone() returns trigger
language plpgsql security invoker set search_path = ''
as $$
begin
  if not exists (select 1 from pg_catalog.pg_timezone_names where name = new.timezone) then
    raise exception using errcode = '23514', message = 'Invalid timezone';
  end if;
  return new;
end;
$$;
create trigger clinic_timezone before insert or update of timezone on app.clinics
for each row execute function private.validate_clinic_timezone();

-- Private lookup avoids recursive membership policies. No arbitrary actor parameter.
-- JWTs must have been verified by Auth/PostgREST before reaching these functions.
create function private.request_session_id() returns uuid
language plpgsql stable security invoker set search_path = ''
as $$
begin
  return nullif(auth.jwt()->>'session_id', '')::uuid;
exception when invalid_text_representation then
  return null;
end;
$$;
create function private.active_user_id() returns uuid
language sql stable security definer set search_path = ''
as $$
  select u.id from app.users u
  join auth.sessions s on s.user_id = u.id
  where u.id = (select auth.uid()) and u.active
    and s.id = (select private.request_session_id())
    and (s.not_after is null or s.not_after > now());
$$;
create function private.can_enter_clinic(target uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from app.users u join app.clinics c on c.id = target and c.active
    where u.id = (select private.active_user_id())
      and (not u.is_dev or auth.jwt()->>'aal' = 'aal2')
      and (
        (u.is_dev and auth.jwt()->>'aal' = 'aal2')
        or exists (
          select 1 from app.memberships m
          where m.user_id = u.id and m.clinic_id = c.id and m.active
          and exists (select 1 from app.membership_roles r
                      where r.clinic_id = m.clinic_id and r.membership_id = m.id)
          and (not exists (select 1 from app.membership_roles r
                           where r.clinic_id = m.clinic_id and r.membership_id = m.id
                             and r.role = 'administrator')
               or auth.jwt()->>'aal' = 'aal2')
        )
      )
  );
$$;
create function private.current_clinic_id() returns uuid
language sql stable security definer set search_path = ''
as $$
  select c.clinic_id from private.clinic_contexts c
  where c.session_id = (select private.request_session_id())
    and c.user_id = (select private.active_user_id())
    and private.can_enter_clinic(c.clinic_id);
$$;
create function private.is_clinic_administrator(target uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select target = (select private.current_clinic_id())
    and auth.jwt()->>'aal' = 'aal2'
    and exists (
      select 1 from app.memberships m
      join app.membership_roles r on r.clinic_id = m.clinic_id and r.membership_id = m.id
      where m.user_id = (select private.active_user_id()) and m.active
        and m.clinic_id = target and r.role = 'administrator'
    );
$$;
create function private.is_own_membership(target_clinic uuid, target_membership uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from app.memberships m
    where m.id = target_membership and m.clinic_id = target_clinic and m.active
      and m.user_id = (select private.active_user_id()));
$$;
create function private.can_read_audit(target uuid) returns boolean
language sql stable security definer set search_path = ''
as $$
  select target = (select private.current_clinic_id()) and (
    private.is_clinic_administrator(target)
    or exists (select 1 from app.users u where u.id = (select private.active_user_id())
      and u.is_dev and auth.jwt()->>'aal' = 'aal2')
  );
$$;
create function private.select_clinic(target uuid) returns uuid
language plpgsql security definer set search_path = ''
as $$
declare
  actor uuid := private.active_user_id();
  session uuid := private.request_session_id();
begin
  if actor is null or not private.can_enter_clinic(target) then
    raise exception using errcode = '42501', message = 'Access denied';
  end if;
  insert into private.clinic_contexts(session_id, user_id, clinic_id)
  values (session, actor, target)
  on conflict (session_id) do update
    set user_id = excluded.user_id, clinic_id = excluded.clinic_id, selected_at = now();
  insert into audit.events(clinic_id, actor_user_id, action)
    values (target, actor, 'clinic.selected');
  return target;
end;
$$;
-- The only exposed mutation: authorized clinic selection, with atomic audit.
create function api.select_clinic(clinic_id uuid) returns uuid
language sql security invoker set search_path = ''
as $$ select private.select_clinic(clinic_id); $$;
create function api.current_clinic() returns uuid
language sql stable security invoker set search_path = ''
as $$ select private.current_clinic_id(); $$;
create function api.list_clinics() returns table(id uuid, name text, timezone text)
language sql stable security invoker set search_path = ''
as $$ select c.id, c.name, c.timezone from app.clinics c order by c.name, c.id; $$;

alter table app.users enable row level security;
alter table app.clinics enable row level security;
alter table app.memberships enable row level security;
alter table app.membership_roles enable row level security;
alter table private.clinic_contexts enable row level security;
alter table audit.events enable row level security;
-- No table writes for authenticated/anon/service_role in this foundation.
grant select on app.users, app.clinics, app.memberships, app.membership_roles, audit.events to authenticated;
create policy users_self on app.users for select to authenticated
using (id = (select private.active_user_id()));
-- This is the allowed-clinic DIRECTORY, not access to clinical records.
create policy clinics_directory on app.clinics for select to authenticated
using (private.can_enter_clinic(id));
create policy memberships_read on app.memberships for select to authenticated
using (
  (active and user_id = (select private.active_user_id()))
  or private.is_clinic_administrator(clinic_id)
);
create policy roles_read on app.membership_roles for select to authenticated
using (
  private.is_own_membership(clinic_id, membership_id)
  or private.is_clinic_administrator(clinic_id)
);
create policy audit_admin on audit.events for select to authenticated
using (private.can_read_audit(clinic_id));
-- private.clinic_contexts intentionally has no grants or policies for direct reads.

revoke all on all functions in schema private, api from public, anon, authenticated, service_role;
grant execute on function private.request_session_id(), private.active_user_id(),
  private.can_enter_clinic(uuid), private.current_clinic_id(),
  private.is_clinic_administrator(uuid), private.is_own_membership(uuid, uuid),
  private.can_read_audit(uuid), private.select_clinic(uuid), api.select_clinic(uuid),
  api.current_clinic(), api.list_clinics()
to authenticated;
comment on schema private is 'Not exposed via Data API. Guarded lookup functions; no direct table access.';
comment on table app.membership_roles is 'Roles do not yet authorize scheduling; doctor+reception scope remains own.';
comment on function private.active_user_id() is 'Fails closed for inactive users, missing/revoked/expired Auth sessions.';
