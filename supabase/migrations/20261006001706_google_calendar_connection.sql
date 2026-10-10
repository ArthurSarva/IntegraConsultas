-- Google credentials remain in an unexposed schema, encrypted by the application.
create table private.google_connections (
 clinic_id uuid not null, membership_id uuid not null, credential text not null check(length(credential) between 40 and 16000),
 calendar_id text not null check(length(calendar_id) between 1 and 1024), calendar_name text not null check(length(calendar_name) between 1 and 256),
 connected_at timestamptz not null default now(), primary key(clinic_id,membership_id),
 foreign key(clinic_id,membership_id) references app.memberships(clinic_id,id)
);
create table private.google_oauth_requests (
 clinic_id uuid not null, membership_id uuid not null, user_id uuid not null references app.users(id),
 session_id uuid not null references auth.sessions(id) on delete cascade,
 state_hash text not null check(state_hash ~ '^[a-f0-9]{64}$'), proof uuid not null default gen_random_uuid(),
 phase text not null default 'started' check(phase in('started','verified')),
 expires_at timestamptz not null default now()+interval '10 minutes', created_at timestamptz not null default now(),
 primary key(clinic_id,membership_id), unique(proof),
 foreign key(clinic_id,membership_id) references app.memberships(clinic_id,id)
);
alter table private.google_connections enable row level security;
alter table private.google_oauth_requests enable row level security;
create policy google_connections_private on private.google_connections for all using(false) with check(false);
create policy google_requests_private on private.google_oauth_requests for all using(false) with check(false);
revoke all on private.google_connections,private.google_oauth_requests from public,anon,authenticated,service_role;

alter table audit.events drop constraint events_action_check;
alter table audit.events add constraint events_action_check check(action in
 ('clinic.selected','clinic.created','administrator.linked','administrator.invitation_cancelled','team.linked','administrator.doctor_configured',
 'patient.created','patient.updated','patient.viewed','patient.searched','patient.deleted','patient.archived','administrator.removed','team.removed','administrator.doctor_disabled',
 'availability.created','availability.removed','doctor.duration_updated','block.created','block.removed',
 'appointment.created','appointment.rescheduled','appointment.confirmed','appointment.completed','appointment.cancelled','appointment.no_show','appointment.replaced','agenda.viewed','appointment.viewed','automation.viewed',
 'google.connected','google.disconnected'));

create function private.google_owner(target_clinic uuid) returns uuid
language plpgsql stable security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); member uuid:=(permission->>'doctor_membership')::uuid;
begin
 if member is null then raise exception using errcode='42501',message='Doctor access required'; end if;
 return member;
end $$;
create function private.google_status(target_clinic uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare member uuid:=private.google_owner(target_clinic); result jsonb;
begin
 select jsonb_build_object('connected',true,'calendar_name',calendar_name,'connected_at',connected_at) into result
 from private.google_connections where clinic_id=target_clinic and membership_id=member;
 return coalesce(result,jsonb_build_object('connected',false));
end $$;
create function private.google_begin(target_clinic uuid,hash text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare member uuid:=private.google_owner(target_clinic);
begin
 if hash is null or hash !~ '^[a-f0-9]{64}$' then raise exception using errcode='22023',message='Invalid OAuth state'; end if;
 if exists(select 1 from private.google_connections where clinic_id=target_clinic and membership_id=member) then
  raise exception using errcode='22023',message='Disconnect before replacing connection'; end if;
 insert into private.google_oauth_requests(clinic_id,membership_id,user_id,session_id,state_hash)
 values(target_clinic,member,private.active_user_id(),private.request_session_id(),hash)
 on conflict(clinic_id,membership_id) do update set user_id=excluded.user_id,session_id=excluded.session_id,state_hash=excluded.state_hash,
  proof=gen_random_uuid(),phase='started',expires_at=now()+interval '10 minutes',created_at=now();
 return jsonb_build_object('membership',member,'session',private.request_session_id());
end $$;
create function private.google_verify(target_clinic uuid,hash text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare member uuid:=private.google_owner(target_clinic); result uuid;
begin
 update private.google_oauth_requests set phase='verified' where clinic_id=target_clinic and membership_id=member
 and user_id=private.active_user_id() and session_id=private.request_session_id() and state_hash=hash and phase='started' and expires_at>now()
 returning proof into result;
 if result is null then raise exception using errcode='42501',message='Expired or invalid OAuth state'; end if;
 return jsonb_build_object('proof',result,'membership',member,'session',private.request_session_id());
end $$;
create function private.google_save(target_clinic uuid,member uuid,confirmation uuid,cipher text,calendar text,label text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare request private.google_oauth_requests;
begin
 if current_setting('role',true)<>'service_role' then raise exception using errcode='42501',message='Technical role required'; end if;
 select * into request from private.google_oauth_requests where clinic_id=target_clinic and membership_id=member and proof=confirmation
 and phase='verified' and expires_at>now() for update;
 if not found or not exists(select 1 from app.memberships m join app.users u on u.id=m.user_id and u.active and not u.is_dev
 join app.clinics c on c.id=m.clinic_id and c.active
 join app.membership_roles r on r.clinic_id=m.clinic_id and r.membership_id=m.id and r.role='doctor'
 join auth.sessions s on s.id=request.session_id and s.user_id=m.user_id and (s.not_after is null or s.not_after>now())
 join private.clinic_contexts ctx on ctx.session_id=s.id and ctx.user_id=m.user_id and ctx.clinic_id=m.clinic_id
 where m.clinic_id=target_clinic and m.id=member and m.user_id=request.user_id and m.active) then
 raise exception using errcode='42501',message='Access denied'; end if;
 insert into private.google_connections(clinic_id,membership_id,credential,calendar_id,calendar_name) values(target_clinic,member,cipher,calendar,label);
 delete from private.google_oauth_requests where clinic_id=target_clinic and membership_id=member;
 insert into audit.events(clinic_id,actor_user_id,action) values(target_clinic,request.user_id,'google.connected');
 return jsonb_build_object('status','saved');
end $$;
create function private.google_disconnect(target_clinic uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare member uuid:=private.google_owner(target_clinic);
begin
 delete from private.google_oauth_requests where clinic_id=target_clinic and membership_id=member;
 delete from private.google_connections where clinic_id=target_clinic and membership_id=member;
 if found then insert into audit.events(clinic_id,actor_user_id,action) values(target_clinic,private.active_user_id(),'google.disconnected'); end if;
 return jsonb_build_object('status','saved');
end $$;

create function api.google_status(clinic_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.google_status($1); $$;
create function api.google_begin(clinic_id uuid,state_hash text) returns jsonb language sql security invoker set search_path='' as $$ select private.google_begin($1,$2); $$;
create function api.google_verify(clinic_id uuid,state_hash text) returns jsonb language sql security invoker set search_path='' as $$ select private.google_verify($1,$2); $$;
create function api.google_disconnect(clinic_id uuid) returns jsonb language sql security invoker set search_path='' as $$ select private.google_disconnect($1); $$;
create function api.google_save(clinic_id uuid,membership_id uuid,proof uuid,credential text,calendar_id text,calendar_name text) returns jsonb language sql security invoker set search_path='' as $$ select private.google_save($1,$2,$3,$4,$5,$6); $$;
do $permissions$ declare item record; begin
 for item in select p.oid::regprocedure signature,p.proname,n.nspname from pg_proc p join pg_namespace n on n.oid=p.pronamespace
 where n.nspname in('private','api') and p.proname in('google_owner','google_status','google_begin','google_verify','google_save','google_disconnect') loop
 execute format('revoke all on function %s from public,anon,authenticated,service_role',item.signature);
 if item.proname='google_save' then execute format('grant execute on function %s to service_role',item.signature);
 else execute format('grant execute on function %s to authenticated',item.signature); end if;
 end loop;
end $permissions$;
