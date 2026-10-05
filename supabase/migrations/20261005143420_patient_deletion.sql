-- Opaque references preserve audit targets after demographic deletion.
create table app.patient_references (
 id uuid primary key,
 clinic_id uuid not null references app.clinics(id) on delete restrict,
 has_consultation boolean not null default false,
 unique(clinic_id,id)
);
insert into app.patient_references(id,clinic_id) select id,clinic_id from app.patients;
alter table app.patient_references enable row level security;
create policy patient_references_internal on app.patient_references for select to authenticated using(false);
revoke all on app.patient_references from public,anon,authenticated,service_role;
alter table app.patients add column archived_at timestamptz;
alter table app.patients add constraint patients_reference_fk foreign key(clinic_id,id) references app.patient_references(clinic_id,id) on delete restrict;
alter table audit.events drop constraint events_patient_fk;
alter table audit.events add constraint events_patient_fk foreign key(clinic_id,target_patient_id) references app.patient_references(clinic_id,id) on delete restrict;
alter table app.patients drop constraint patients_clinic_id_cpf_key;
create unique index patients_active_cpf_idx on app.patients(clinic_id,cpf) where archived_at is null;
create function private.create_patient_reference() returns trigger
language plpgsql security invoker set search_path='' as $$
begin
 insert into app.patient_references(id,clinic_id) values(new.id,new.clinic_id);
 return new;
end $$;
create trigger patient_reference before insert on app.patients for each row execute function private.create_patient_reference();
revoke all on function private.create_patient_reference() from public,anon,authenticated,service_role;

alter table audit.events drop constraint events_action_check;
alter table audit.events add constraint events_action_check check(action in
 ('clinic.selected','clinic.created','administrator.linked','administrator.invitation_cancelled','team.linked','administrator.doctor_configured',
 'patient.created','patient.updated','patient.viewed','patient.searched','patient.deleted','patient.archived'));

create or replace function private.can_read_patient(target_clinic uuid,target_patient uuid,own_only boolean) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare permission jsonb;
begin
 if own_only is null or private.active_user_id() is null or private.current_clinic_id() is distinct from target_clinic then return false; end if;
 permission:=private.patient_permissions(target_clinic);
 if not exists(select 1 from app.patients where clinic_id=target_clinic and id=target_patient and archived_at is null) then return false; end if;
 if permission->>'scope'='clinic' and not own_only then return true; end if;
 return exists(select 1 from app.patient_doctors d where d.clinic_id=target_clinic and d.patient_id=target_patient
  and d.membership_id=(permission->>'doctor_membership')::uuid);
end $$;

-- The future scheduling transaction must call this before registering any consultation.
-- This monotonic marker has no client EXECUTE grant and cannot be cleared through the API.
create function private.retain_patient_for_consultation(target_clinic uuid,target_patient uuid) returns void
language plpgsql security definer set search_path='' as $$
begin
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('patients:'||target_clinic::text,0));
 perform 1 from app.patients where clinic_id=target_clinic and id=target_patient and archived_at is null for update;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 update app.patient_references set has_consultation=true where clinic_id=target_clinic and id=target_patient;
end $$;
revoke all on function private.retain_patient_for_consultation(uuid,uuid) from public,anon,authenticated,service_role;

create function private.delete_patient(target_clinic uuid,target_patient uuid,expected_version integer,operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); actor uuid:=(permission->>'actor')::uuid;
 member uuid; prior audit.events%rowtype; person app.patients%rowtype; retained boolean; action_name text;
 fingerprint text:=encode(sha256(convert_to(jsonb_build_array(operation_id,actor,target_clinic,target_patient,expected_version)::text,'UTF8')),'hex');
begin
 if permission->>'scope'<>'clinic' or not(permission->>'can_write')::boolean then raise exception using errcode='42501',message='Access denied'; end if;
 if target_patient is null or operation_id is null or expected_version is null or expected_version<1 then raise exception using errcode='22023',message='Invalid deletion input'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(operation_id::text,0));
 perform 1 from app.users where id=actor and active for update;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 select id into member from app.memberships where clinic_id=target_clinic and user_id=actor and active for update;
 perform 1 from app.membership_roles where clinic_id=target_clinic and membership_id=member for share;
 permission:=private.patient_permissions(target_clinic);
 if permission->>'scope'<>'clinic' or not(permission->>'can_write')::boolean then raise exception using errcode='42501',message='Access denied'; end if;
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('patients:'||target_clinic::text,0));
 select * into prior from audit.events where request_id=operation_id;
 if found then
  if prior.actor_user_id<>actor or prior.clinic_id<>target_clinic or prior.target_patient_id<>target_patient
   or prior.action not in('patient.deleted','patient.archived') or prior.request_fingerprint<>fingerprint then
   raise exception using errcode='42501',message='Access denied'; end if;
  return jsonb_build_object('status',case when prior.action='patient.deleted' then 'deleted' else 'archived' end);
 end if;
 select * into person from app.patients where clinic_id=target_clinic and id=target_patient and archived_at is null for update;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 if person.version<>expected_version then return jsonb_build_object('status','conflict'); end if;
 select has_consultation into retained from app.patient_references where clinic_id=target_clinic and id=target_patient for update;
 if retained then
  update app.patients set archived_at=now(),updated_at=now(),version=version+1 where clinic_id=target_clinic and id=target_patient;
  action_name:='patient.archived';
 else
  delete from app.patient_doctors where clinic_id=target_clinic and patient_id=target_patient;
  delete from app.patients where clinic_id=target_clinic and id=target_patient;
  action_name:='patient.deleted';
 end if;
 insert into audit.events(clinic_id,actor_user_id,target_patient_id,action,request_id,request_fingerprint)
  values(target_clinic,actor,target_patient,action_name,operation_id,fingerprint);
 return jsonb_build_object('status',case when retained then 'archived' else 'deleted' end);
end $$;
create function api.delete_patient(clinic_id uuid,patient_id uuid,expected_version integer,operation_id uuid) returns jsonb
language sql security invoker set search_path='' as $$ select private.delete_patient(clinic_id,patient_id,expected_version,operation_id); $$;
revoke all on function private.delete_patient(uuid,uuid,integer,uuid),api.delete_patient(uuid,uuid,integer,uuid) from public,anon,authenticated,service_role;
grant execute on function private.delete_patient(uuid,uuid,integer,uuid),api.delete_patient(uuid,uuid,integer,uuid) to authenticated;
comment on table app.patient_references is 'Opaque clinic-local audit targets; no demographics. has_consultation is a monotonic retention marker for future guarded scheduling transactions.';

-- Exclude archived CPFs from active duplicate checks.
create or replace function private.save_patient(target_clinic uuid,target_patient uuid,person_name text,birth date,contact_phone text,contact_email text,document_cpf text,
 expected_version integer,allow_duplicate boolean,own_only boolean,operation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); actor uuid:=(permission->>'actor')::uuid;
 member uuid; prior audit.events%rowtype; existing app.patients%rowtype; patient uuid; matches jsonb; action_name text;
 clean_name text:=regexp_replace(btrim(person_name),'\s+',' ','g'); clean_email text:=nullif(lower(btrim(contact_email)),''); clean_cpf text:=nullif(btrim(document_cpf),'');
 fingerprint text; today date;
begin
 if not(permission->>'can_write')::boolean then raise exception using errcode='42501',message='Access denied'; end if;
 select (now() at time zone timezone)::date into today from app.clinics where id=target_clinic;
 if operation_id is null or allow_duplicate is null or own_only is null or (own_only and permission->>'doctor_membership' is null)
  or clean_name is null or length(clean_name) not between 1 and 120 or clean_name ~ '[[:cntrl:]]'
  or birth is null or birth<'0001-01-01'::date or birth>today or contact_phone is null or contact_phone !~ '^\+[1-9][0-9]{7,14}$'
  or (clean_email is not null and (length(clean_email)>254 or clean_email !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'))
  or not private.valid_patient_cpf(clean_cpf)
  or (target_patient is null and expected_version is not null) or (target_patient is not null and (expected_version is null or expected_version<1)) then
  raise exception using errcode='22023',message='Invalid patient input';
 end if;
 fingerprint:=encode(sha256(convert_to(jsonb_build_array(operation_id,actor,target_clinic,target_patient,clean_name,birth,contact_phone,clean_email,clean_cpf,expected_version,allow_duplicate,own_only)::text,'UTF8')),'hex');
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended(operation_id::text,0));
 perform 1 from app.users where id=actor and active for update;
 if not found then raise exception using errcode='42501',message='Access denied'; end if;
 select m.id into member from app.memberships m where m.clinic_id=target_clinic and m.user_id=actor and m.active for update;
 if member is not null then perform 1 from app.membership_roles where clinic_id=target_clinic and membership_id=member for share; end if;
 permission:=private.patient_permissions(target_clinic);
 if not(permission->>'can_write')::boolean then raise exception using errcode='42501',message='Access denied'; end if;
 -- A short clinic-local transaction serializes duplicate checks and edits.
 perform pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('patients:'||target_clinic::text,0));
 if target_patient is not null and not private.can_read_patient(target_clinic,target_patient,own_only) then raise exception using errcode='42501',message='Access denied'; end if;
 if target_patient is not null and not private.can_edit_patient(target_clinic,target_patient) then raise exception using errcode='42501',message='Access denied'; end if;
 select * into prior from audit.events where request_id=operation_id;
 if found then
  if prior.actor_user_id<>actor or prior.action not in('patient.created','patient.updated') or prior.request_fingerprint<>fingerprint
   or not private.can_read_patient(target_clinic,prior.target_patient_id,own_only) then raise exception using errcode='42501',message='Access denied'; end if;
  return jsonb_build_object('status','saved','id',prior.target_patient_id);
 end if;
 if target_patient is not null then
  select * into existing from app.patients where clinic_id=target_clinic and id=target_patient for update;
  if not found then raise exception using errcode='42501',message='Access denied'; end if;
  if existing.version<>expected_version then return jsonb_build_object('status','conflict'); end if;
 end if;
 if clean_cpf is not null and exists(select 1 from app.patients p where p.clinic_id=target_clinic and p.cpf=clean_cpf and p.archived_at is null and p.id is distinct from target_patient) then
  return jsonb_build_object('status','cpf_duplicate');
 end if;
 select coalesce(jsonb_agg(jsonb_build_object('id',p.id,'display_name',p.display_name,'birth_date',p.birth_date,'phone',p.phone)),'[]'::jsonb) into matches
 from(select id,display_name,birth_date,phone from app.patients p where p.clinic_id=target_clinic and p.id is distinct from target_patient
  and private.can_read_patient(target_clinic,p.id,own_only)
  and (((target_patient is null or contact_phone is distinct from existing.phone) and p.phone=contact_phone)
   or ((target_patient is null or private.patient_name_key(clean_name) is distinct from existing.name_key or birth is distinct from existing.birth_date)
    and p.name_key=private.patient_name_key(clean_name) and p.birth_date=birth)) order by p.name_key,p.id limit 3) p;
 if jsonb_array_length(matches)>0 and not allow_duplicate then return jsonb_build_object('status','possible_duplicate','matches',matches); end if;
 if target_patient is null then
  insert into app.patients(clinic_id,display_name,birth_date,phone,email,cpf) values(target_clinic,clean_name,birth,contact_phone,clean_email,clean_cpf) returning id into patient;
  if permission->>'scope'='own' or own_only then
   insert into app.patient_doctors(clinic_id,patient_id,membership_id) values(target_clinic,patient,(permission->>'doctor_membership')::uuid);
  end if;
  action_name:='patient.created';
 else
  patient:=target_patient; action_name:='patient.updated';
  update app.patients set display_name=clean_name,birth_date=birth,phone=contact_phone,email=clean_email,cpf=clean_cpf,version=version+1,updated_at=now() where clinic_id=target_clinic and id=patient;
 end if;
 insert into audit.events(clinic_id,actor_user_id,target_patient_id,action,request_id,request_fingerprint) values(target_clinic,actor,patient,action_name,operation_id,fingerprint);
 return jsonb_build_object('status','saved','id',patient);
end $$;

