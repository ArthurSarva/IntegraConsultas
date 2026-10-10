-- Allow cold starts and bounded Google requests without blocking the cron transaction.
-- No outgoing call until deployment and explicit secure configuration are complete.
create or replace function private.dispatch_google_worker() returns boolean
language plpgsql security definer set search_path='' as $$
declare endpoint text; secret text;
begin
 if to_regclass('vault.decrypted_secrets') is null or not exists(select 1 from pg_extension where extname='pg_net') then return false; end if;
 execute 'select decrypted_secret from vault.decrypted_secrets where name=$1' into endpoint using 'integraconsultas_google_worker_url';
 execute 'select decrypted_secret from vault.decrypted_secrets where name=$1' into secret using 'integraconsultas_google_worker_secret';
 if endpoint is null or endpoint !~ '^https://[a-z0-9]{20}\.supabase\.co/functions/v1/google-sync$' or secret is null or length(secret)<40 then return false; end if;
 execute 'select net.http_post(url:=$1,headers:=$2,body:=$3,timeout_milliseconds:=120000)' using endpoint,jsonb_build_object('Content-Type','application/json','X-Worker-Secret',secret),'{}'::jsonb;
 return true;
end $$;
revoke all on function private.dispatch_google_worker() from public,anon,authenticated,service_role;


