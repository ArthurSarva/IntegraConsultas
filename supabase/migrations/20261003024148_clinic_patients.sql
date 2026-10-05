-- Patient registry is clinic-local; no clinical notes or direct client table access.
create function private.patient_name_key(value text) returns text
language sql immutable strict security invoker set search_path='' as $$
 select translate(lower(regexp_replace(btrim(value),'\s+',' ','g')),'áàâãäéèêëíìîïóòôõöúùûüç','aaaaaeeeeiiiiooooouuuuc');
$$;
create function private.valid_patient_cpf(value text) returns boolean
language plpgsql immutable security invoker set search_path='' as $$
declare digit integer; total integer; i integer; stage integer;
begin
 if value is null then return true; end if;
 if value !~ '^[0-9]{11}$' or value=repeat(substr(value,1,1),11) then return false; end if;
 for stage in 10..11 loop
  total:=0;
  for i in 1..stage-1 loop total:=total+substr(value,i,1)::integer*(stage+1-i); end loop;
  digit:=(total*10)%11; if digit=10 then digit:=0; end if;
  if digit<>substr(value,stage,1)::integer then return false; end if;
 end loop;
 return true;
end $$;

create table app.patients (
 id uuid primary key default gen_random_uuid(),
 clinic_id uuid not null references app.clinics(id) on delete restrict,
 display_name text not null check(length(display_name) between 1 and 120 and display_name=btrim(display_name) and display_name !~ '[[:cntrl:]]'),
 name_key text generated always as (private.patient_name_key(display_name)) stored,
 birth_date date not null check(birth_date>='0001-01-01'::date),
 phone text not null check(phone ~ '^\+[1-9][0-9]{7,14}$'),
 email text check(email is null or (length(email)<=254 and email=lower(btrim(email)) and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$')),
 cpf text check(private.valid_patient_cpf(cpf)),
 version integer not null default 1 check(version>0),
 created_at timestamptz not null default now(),
 updated_at timestamptz not null default now(),
 unique(clinic_id,id),
 unique(clinic_id,cpf)
);
create index patients_clinic_name_idx on app.patients(clinic_id,name_key,birth_date,id);
create index patients_clinic_phone_idx on app.patients(clinic_id,phone);
create table app.patient_doctors (
 clinic_id uuid not null,
 patient_id uuid not null,
 membership_id uuid not null,
 primary key(clinic_id,patient_id,membership_id),
 foreign key(clinic_id,patient_id) references app.patients(clinic_id,id) on delete restrict,
 foreign key(clinic_id,membership_id) references app.memberships(clinic_id,id) on delete restrict
);
create index patient_doctors_membership_idx on app.patient_doctors(clinic_id,membership_id,patient_id);
alter table app.patients enable row level security;
alter table app.patient_doctors enable row level security;
revoke all on app.patients,app.patient_doctors from public,anon,authenticated,service_role;

create function private.validate_patient_birth_date() returns trigger
language plpgsql security invoker set search_path='' as $$
declare today date;
begin
 select (now() at time zone c.timezone)::date into today from app.clinics c where c.id=new.clinic_id;
 if new.birth_date>today then raise exception using errcode='22023',message='Invalid birth date'; end if;
 return new;
end $$;
create trigger patient_birth_date before insert or update of birth_date,clinic_id on app.patients
 for each row execute function private.validate_patient_birth_date();

alter table audit.events add column target_patient_id uuid;
alter table audit.events add constraint events_patient_fk foreign key(clinic_id,target_patient_id) references app.patients(clinic_id,id) on delete restrict;
create index audit_events_patient_idx on audit.events(clinic_id,target_patient_id) where target_patient_id is not null;
alter table audit.events drop constraint events_action_check;
alter table audit.events add constraint events_action_check check(action in
 ('clinic.selected','clinic.created','administrator.linked','administrator.invitation_cancelled','team.linked','administrator.doctor_configured','patient.created','patient.updated','patient.viewed','patient.searched'));
alter table audit.events drop constraint events_request_check;
alter table audit.events add constraint events_request_check check(
 (request_id is null and request_fingerprint is null) or
 (request_id is not null and request_fingerprint is not null and length(request_fingerprint) in(32,64)));

create function private.patient_permissions(target_clinic uuid) returns jsonb
language plpgsql stable security definer set search_path='' as $$
declare actor uuid:=private.active_user_id(); member uuid; admin boolean; reception_clinic boolean; doctor boolean; reception_own boolean;
begin
 if actor is null or target_clinic is null or private.current_clinic_id() is distinct from target_clinic then
  raise exception using errcode='42501',message='Access denied';
 end if;
 if exists(select 1 from app.users where id=actor and is_dev and auth.jwt()->>'aal'='aal2') then
  return jsonb_build_object('actor',actor,'scope','clinic','can_write',false,'doctor_membership',null);
 end if;
 select m.id into member from app.memberships m where m.clinic_id=target_clinic and m.user_id=actor and m.active;
 select coalesce(bool_or(r.role='administrator'),false),coalesce(bool_or(r.role='reception' and r.scope='clinic'),false),
  coalesce(bool_or(r.role='doctor'),false),coalesce(bool_or(r.role='reception' and r.scope='own'),false)
 into admin,reception_clinic,doctor,reception_own from app.membership_roles r where r.clinic_id=target_clinic and r.membership_id=member;
 if not(admin or reception_clinic or doctor) then raise exception using errcode='42501',message='Access denied'; end if;
 return jsonb_build_object('actor',actor,'scope',case when admin or (reception_clinic and not doctor) then 'clinic' else 'own' end,
  'can_write',admin or reception_clinic or (doctor and reception_own),'doctor_membership',case when doctor then member else null end);
end $$;
create function private.can_read_patient(target_clinic uuid,target_patient uuid,own_only boolean) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare permission jsonb;
begin
 if own_only is null or private.active_user_id() is null or private.current_clinic_id() is distinct from target_clinic then return false; end if;
 permission:=private.patient_permissions(target_clinic);
 if permission->>'scope'='clinic' and not own_only then return true; end if;
 return exists(select 1 from app.patient_doctors d where d.clinic_id=target_clinic and d.patient_id=target_patient
  and d.membership_id=(permission->>'doctor_membership')::uuid);
end $$;
create policy patients_read on app.patients for select to authenticated using(private.can_read_patient(clinic_id,id,false));
create policy patient_doctors_read on app.patient_doctors for select to authenticated using(private.can_read_patient(clinic_id,patient_id,false));

create function private.can_edit_patient(target_clinic uuid,target_patient uuid) returns boolean
language plpgsql stable security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic);
begin
 if not(permission->>'can_write')::boolean or not private.can_read_patient(target_clinic,target_patient,false) then return false; end if;
 if permission->>'scope'='clinic' then return true; end if;
 -- Shared demographics remain clinic-managed until the shared-patient policy is approved.
 return not exists(select 1 from app.patient_doctors d where d.clinic_id=target_clinic and d.patient_id=target_patient
  and d.membership_id is distinct from (permission->>'doctor_membership')::uuid);
end $$;

create function private.search_patients(target_clinic uuid,search_term text,page_number integer,own_only boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); records jsonb; more boolean;
 term text:=private.patient_name_key(coalesce(search_term,'')); digits text:=regexp_replace(coalesce(search_term,''),'[^0-9]','','g');
begin
 if search_term is null or length(search_term)>120 or (length(btrim(search_term)) between 1 and 2)
  or page_number is null or page_number not between 0 and 10000 or own_only is null
  or (own_only and permission->>'doctor_membership' is null) then
  raise exception using errcode='22023',message='Invalid patient search';
 end if;
 with matches as (
  select p.id,p.display_name,p.birth_date,p.phone,p.cpf from app.patients p where p.clinic_id=target_clinic
   and private.can_read_patient(p.clinic_id,p.id,own_only)
   and (term='' or position(term in p.name_key)>0 or (length(digits)>=3 and position(digits in p.phone)>0)
    or (length(digits)=11 and p.cpf=digits) or position(lower(btrim(search_term)) in coalesce(p.email,''))>0)
  order by p.name_key,p.id limit 26 offset page_number*25
 ), numbered as(select *,row_number() over() as n from matches)
 select coalesce(jsonb_agg(jsonb_build_object('id',id,'display_name',display_name,'birth_date',birth_date,'phone',phone,'cpf_suffix',right(cpf,4)) order by n) filter(where n<=25),'[]'::jsonb),count(*)>25
 into records,more from numbered;
 insert into audit.events(clinic_id,actor_user_id,action) values(target_clinic,(permission->>'actor')::uuid,'patient.searched');
 return jsonb_build_object('records',records,'has_more',more,'page',page_number);
end $$;
create function private.get_patient(target_clinic uuid,target_patient uuid,own_only boolean) returns jsonb
language plpgsql security definer set search_path='' as $$
declare permission jsonb:=private.patient_permissions(target_clinic); result jsonb;
begin
 if not private.can_read_patient(target_clinic,target_patient,own_only) then return null; end if;
 select jsonb_build_object('id',p.id,'display_name',p.display_name,'birth_date',p.birth_date,'phone',p.phone,'email',p.email,'cpf',p.cpf,'version',p.version,'can_edit',private.can_edit_patient(target_clinic,p.id)) into result
  from app.patients p where p.clinic_id=target_clinic and p.id=target_patient;
 if result is not null then
  insert into audit.events(clinic_id,actor_user_id,target_patient_id,action) values(target_clinic,(permission->>'actor')::uuid,target_patient,'patient.viewed');
 end if;
 return result;
end $$;
create function private.save_patient(target_clinic uuid,target_patient uuid,person_name text,birth date,contact_phone text,contact_email text,document_cpf text,
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
 if clean_cpf is not null and exists(select 1 from app.patients p where p.clinic_id=target_clinic and p.cpf=clean_cpf and p.id is distinct from target_patient) then
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

create function api.patient_permissions(clinic_id uuid) returns jsonb language sql stable security invoker set search_path='' as $$ select private.patient_permissions(clinic_id); $$;
create function api.search_patients(clinic_id uuid,search_term text,page_number integer,own_only boolean) returns jsonb language sql security invoker set search_path='' as $$ select private.search_patients(clinic_id,search_term,page_number,own_only); $$;
create function api.get_patient(clinic_id uuid,patient_id uuid,own_only boolean) returns jsonb language sql security invoker set search_path='' as $$ select private.get_patient(clinic_id,patient_id,own_only); $$;
create function api.save_patient(clinic_id uuid,patient_id uuid,display_name text,birth_date date,phone text,email text,cpf text,expected_version integer,allow_duplicate boolean,own_only boolean,operation_id uuid) returns jsonb
 language sql security invoker set search_path='' as $$ select private.save_patient(clinic_id,patient_id,display_name,birth_date,phone,email,cpf,expected_version,allow_duplicate,own_only,operation_id); $$;
revoke all on function private.patient_name_key(text),private.valid_patient_cpf(text),private.validate_patient_birth_date(),
 private.patient_permissions(uuid),private.can_read_patient(uuid,uuid,boolean),private.can_edit_patient(uuid,uuid),private.search_patients(uuid,text,integer,boolean),private.get_patient(uuid,uuid,boolean),
 private.save_patient(uuid,uuid,text,date,text,text,text,integer,boolean,boolean,uuid),api.patient_permissions(uuid),api.search_patients(uuid,text,integer,boolean),api.get_patient(uuid,uuid,boolean),
 api.save_patient(uuid,uuid,text,date,text,text,text,integer,boolean,boolean,uuid) from public,anon,authenticated,service_role;
grant execute on function private.patient_permissions(uuid),private.can_read_patient(uuid,uuid,boolean),private.can_edit_patient(uuid,uuid),private.search_patients(uuid,text,integer,boolean),private.get_patient(uuid,uuid,boolean),
 private.save_patient(uuid,uuid,text,date,text,text,text,integer,boolean,boolean,uuid),api.patient_permissions(uuid),api.search_patients(uuid,text,integer,boolean),api.get_patient(uuid,uuid,boolean),
 api.save_patient(uuid,uuid,text,date,text,text,text,integer,boolean,boolean,uuid) to authenticated;
comment on table app.patient_doctors is 'Clinic-local doctor-patient access. Own-reception creates self-linked patients; future scheduling links consultation patients through guarded functions. No client assignment grants.';
