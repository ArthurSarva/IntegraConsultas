-- PostgreSQL/Supabase runtime. Embedded PGlite does not provide background extensions.
do $schedule$
begin
 if exists(select 1 from pg_catalog.pg_available_extensions where name='pg_cron') then
  create extension if not exists pg_cron with schema pg_catalog;
  perform cron.schedule('integraconsultas-foundation','* * * * *','select private.process_foundation_jobs(25);');
 end if;
end $schedule$;
