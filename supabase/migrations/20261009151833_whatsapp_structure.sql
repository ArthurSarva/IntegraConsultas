-- Dormant structure only: no credential, network call, dispatch job or activation RPC.
alter table app.patients add column whatsapp_enabled boolean not null default true;
alter table app.patients add column whatsapp_version integer not null default 1 check(whatsapp_version>0);
create table private.whatsapp_channels (
 clinic_id uuid primary key references app.clinics(id), id uuid not null default gen_random_uuid(),
 version integer not null default 1 check(version>0), provider text not null default 'meta_cloud' check(provider='meta_cloud'),
 phone text not null check(phone ~ '^\+[1-9][0-9]{7,14}$'), phone_number_id text check(phone_number_id ~ '^[0-9]{5,30}$'),
 waba_id text check(waba_id ~ '^[0-9]{5,30}$'), status text not null default 'draft' check(status in('draft','paused')),
 sends_enabled boolean not null default false check(not sends_enabled), updated_at timestamptz not null default now(),
 unique(clinic_id,id), unique(phone_number_id)
);
create table private.whatsapp_channel_revisions (
 clinic_id uuid not null, channel_id uuid not null, version integer not null,
 phone text not null, phone_number_id text, waba_id text, status text not null check(status in('draft','paused')),
 changed_by uuid not null references app.users(id), created_at timestamptz not null default now(),
 primary key(clinic_id,channel_id,version), foreign key(clinic_id,channel_id) references private.whatsapp_channels(clinic_id,id)
);
create table private.whatsapp_dispatches (
 id uuid primary key default gen_random_uuid(), clinic_id uuid not null, task_id uuid not null,
 channel_id uuid not null, channel_version integer not null, attempt integer not null check(attempt>0),
 provider_message_id text unique, status text not null check(status in('prepared','accepted','delivered','read','failed','unknown')),
 created_at timestamptz not null default now(), unique(clinic_id,task_id,attempt),
 foreign key(clinic_id,task_id) references private.automation_tasks(clinic_id,id),
 foreign key(clinic_id,channel_id,channel_version) references private.whatsapp_channel_revisions(clinic_id,channel_id,version)
);
create index whatsapp_dispatches_task_idx on private.whatsapp_dispatches(clinic_id,task_id);
create table private.whatsapp_receipts (
 clinic_id uuid not null, channel_id uuid not null, channel_version integer not null,
 event_hash text not null check(event_hash ~ '^[a-f0-9]{64}$'), provider_message_id text not null,
 status text not null check(status in('sent','delivered','read','failed')), provider_timestamp timestamptz not null,
 received_at timestamptz not null default now(), primary key(clinic_id,event_hash),
 foreign key(clinic_id,channel_id,channel_version) references private.whatsapp_channel_revisions(clinic_id,channel_id,version)
);
create index whatsapp_receipts_message_idx on private.whatsapp_receipts(provider_message_id);
alter table private.whatsapp_channels enable row level security;
alter table private.whatsapp_channel_revisions enable row level security;
alter table private.whatsapp_dispatches enable row level security;
alter table private.whatsapp_receipts enable row level security;
create policy whatsapp_no_direct_channels on private.whatsapp_channels for all using(false) with check(false);
create policy whatsapp_no_direct_revisions on private.whatsapp_channel_revisions for all using(false) with check(false);
create policy whatsapp_no_direct_dispatches on private.whatsapp_dispatches for all using(false) with check(false);
create policy whatsapp_no_direct_receipts on private.whatsapp_receipts for all using(false) with check(false);
revoke all on private.whatsapp_channels,private.whatsapp_channel_revisions,private.whatsapp_dispatches,private.whatsapp_receipts from public,anon,authenticated,service_role;
-- Extend existing audit action validation without losing actions from prior modules.
do $$ declare previous text; begin
 select pg_get_constraintdef(oid) into previous from pg_constraint where conrelid='audit.events'::regclass and conname='events_action_check';
 alter table audit.events drop constraint events_action_check;
 execute 'alter table audit.events add constraint events_action_check check ('||substr(previous,7)||' or action in (''whatsapp.channel_configured'',''whatsapp.preference_updated'',''whatsapp.channel_viewed''))';
end $$;
create function private.whatsapp_channel(target_clinic uuid) returns jsonb
language plpgsql security definer set search_path='' as $$ declare result jsonb; begin
 perform private.require_team_manager(target_clinic);
 select jsonb_build_object('id',id,'version',version,'phone',phone,'phone_number_id',phone_number_id,'waba_id',waba_id,'status',status,'sends_enabled',false) into result from private.whatsapp_channels where clinic_id=target_clinic;
 insert into audit.events(clinic_id,actor_user_id,action) values(target_clinic,private.active_user_id(),'whatsapp.channel_viewed');
 return coalesce(result,jsonb_build_object('version',0,'status','unconfigured','sends_enabled',false)); end $$;
create function private.configure_whatsapp_channel(target_clinic uuid,expected_version integer,target_phone text,target_phone_id text,target_waba text,target_status text) returns jsonb
language plpgsql security definer set search_path='' as $$ declare actor uuid; row private.whatsapp_channels; begin
 actor:=private.require_team_manager(target_clinic);
 if expected_version is null or expected_version<0 or target_phone is null or target_phone !~ '^\+[1-9][0-9]{7,14}$'
 or (target_phone_id is not null and target_phone_id !~ '^[0-9]{5,30}$') or (target_waba is not null and target_waba !~ '^[0-9]{5,30}$') or target_status is null or target_status not in('draft','paused') then raise exception using errcode='22023',message='Invalid configuration'; end if;
 perform pg_advisory_xact_lock(hashtextextended('whatsapp:'||target_clinic::text,0));
 select * into row from private.whatsapp_channels where clinic_id=target_clinic for update;
 if coalesce(row.version,0)<>expected_version then return jsonb_build_object('status','conflict'); end if;
 if row.version is null then
  insert into private.whatsapp_channels(clinic_id,phone,phone_number_id,waba_id,status) values(target_clinic,target_phone,target_phone_id,target_waba,target_status) returning * into row;
 else
  update private.whatsapp_channels set phone=target_phone,phone_number_id=target_phone_id,waba_id=target_waba,status=target_status,version=version+1,updated_at=now() where clinic_id=target_clinic returning * into row;
 end if;
 insert into private.whatsapp_channel_revisions(clinic_id,channel_id,version,phone,phone_number_id,waba_id,status,changed_by) values(target_clinic,row.id,row.version,row.phone,row.phone_number_id,row.waba_id,row.status,actor);
 insert into audit.events(clinic_id,actor_user_id,action) values(target_clinic,actor,'whatsapp.channel_configured');
 return jsonb_build_object('status','saved','version',row.version,'sends_enabled',false); end $$;
create function private.patient_whatsapp(target_clinic uuid,target_patient uuid,own_only boolean) returns jsonb
language plpgsql stable security definer set search_path='' as $$ declare result jsonb; begin
 if not private.can_read_patient(target_clinic,target_patient,own_only) then raise exception using errcode='42501',message='Access denied'; end if;
 select jsonb_build_object('enabled',whatsapp_enabled,'version',whatsapp_version,'source','automatic_phone','sends_enabled',false) into result from app.patients where clinic_id=target_clinic and id=target_patient and archived_at is null;
 return result; end $$;
create function private.set_patient_whatsapp(target_clinic uuid,target_patient uuid,expected_version integer,enabled boolean,own_only boolean) returns jsonb
language plpgsql security definer set search_path='' as $$ declare permission jsonb; row app.patients; begin
 permission:=private.patient_permissions(target_clinic);
 if not coalesce((permission->>'can_write')::boolean,false) or not private.can_read_patient(target_clinic,target_patient,own_only) then raise exception using errcode='42501',message='Access denied'; end if;
 if enabled is null or expected_version is null or expected_version<1 then raise exception using errcode='22023',message='Invalid preference'; end if;
 select * into row from app.patients where clinic_id=target_clinic and id=target_patient and archived_at is null for update;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 if row.whatsapp_version<>expected_version then return jsonb_build_object('status','conflict'); end if;
 update app.patients set whatsapp_enabled=enabled,whatsapp_version=whatsapp_version+1 where clinic_id=target_clinic and id=target_patient;
 insert into audit.events(clinic_id,actor_user_id,action,target_patient_id) values(target_clinic,private.active_user_id(),'whatsapp.preference_updated',target_patient);
 return jsonb_build_object('status','saved','sends_enabled',false); end $$;
create function api.whatsapp_channel(clinic_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.whatsapp_channel($1); $$;
create function api.configure_whatsapp_channel(clinic_id uuid,expected_version integer,phone text,phone_number_id text,waba_id text,channel_status text) returns jsonb language sql security invoker set search_path='' as $$ select private.configure_whatsapp_channel($1,$2,$3,$4,$5,$6); $$;
create function api.patient_whatsapp(clinic_id uuid,patient_id uuid,own_only boolean) returns jsonb language sql security invoker set search_path='' as $$ select private.patient_whatsapp($1,$2,$3); $$;
create function api.set_patient_whatsapp(clinic_id uuid,patient_id uuid,expected_version integer,enabled boolean,own_only boolean) returns jsonb language sql security invoker set search_path='' as $$ select private.set_patient_whatsapp($1,$2,$3,$4,$5); $$;
do $$ declare f record; begin
 for f in select p.oid::regprocedure signature from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in('api','private') and p.proname=any(array['whatsapp_channel','configure_whatsapp_channel','patient_whatsapp','set_patient_whatsapp']) loop
  execute format('revoke all on function %s from public,anon,authenticated,service_role',f.signature);
  execute format('grant execute on function %s to authenticated',f.signature);
 end loop; end $$;

