-- PUBLIC's built-in function EXECUTE default is global, not per-schema.
-- Schema-level REVOKE cannot cancel it. Every future function needs an explicit grant.
alter default privileges for role postgres revoke execute on functions from public, anon, authenticated, service_role;
