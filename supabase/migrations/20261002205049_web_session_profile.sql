-- Minimal self-only profile and selected-clinic roles for the web authentication gate.
create function api.session_profile() returns jsonb
language sql stable security invoker set search_path = ''
as $$
  select jsonb_build_object(
    'id', u.id, 'display_name', u.display_name, 'is_dev', u.is_dev,
    'requires_mfa', u.is_dev or exists (
      select 1 from app.memberships m join app.membership_roles r
        on r.clinic_id=m.clinic_id and r.membership_id=m.id
      where m.user_id=u.id and m.active and r.role='administrator'
    )
  ) from app.users u where u.id=(select private.active_user_id());
$$;
create function api.workspace() returns jsonb
language sql stable security invoker set search_path = ''
as $$
  select jsonb_build_object(
    'id', c.id, 'name', c.name, 'timezone', c.timezone,
    'roles', coalesce((
      select jsonb_agg(jsonb_build_object('role',r.role,'scope',r.scope) order by r.role)
      from app.memberships m join app.membership_roles r
        on r.clinic_id=m.clinic_id and r.membership_id=m.id
      where m.user_id=(select private.active_user_id()) and m.active and m.clinic_id=c.id
    ), '[]'::jsonb)
  ) from app.clinics c where c.id=(select private.current_clinic_id());
$$;
revoke all on function api.session_profile(), api.workspace() from public, anon, authenticated, service_role;
grant execute on function api.session_profile(), api.workspace() to authenticated;
comment on function api.session_profile() is 'Self-only active identity. Flags guide web flow; authorization stays in DB.';
comment on function api.workspace() is 'Selected authorized clinic only. Does not grant operational CRUD.';
