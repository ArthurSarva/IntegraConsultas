-- Additional synthetic records specifically retained in the recovery archive.
BEGIN;
INSERT INTO auth.users(id,email) VALUES
 ('a1000000-0000-4000-8000-000000000001','restore-a@example.invalid'),
 ('a1000000-0000-4000-8000-000000000002','restore-b@example.invalid');
INSERT INTO auth.sessions(id,user_id,not_after) VALUES
 ('a4000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001',now()+interval '1 day'),
 ('a4000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002',now()+interval '1 day');
INSERT INTO app.users(id,display_name) VALUES
 ('a1000000-0000-4000-8000-000000000001','Recepção fictícia recuperada A'),
 ('a1000000-0000-4000-8000-000000000002','Recepção fictícia recuperada B');
INSERT INTO app.clinics(id,name) VALUES
 ('a2000000-0000-4000-8000-000000000001','Clínica fictícia recuperada A'),
 ('a2000000-0000-4000-8000-000000000002','Clínica fictícia recuperada B');
INSERT INTO app.memberships(id,clinic_id,user_id) VALUES
 ('a3000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','a1000000-0000-4000-8000-000000000001'),
 ('a3000000-0000-4000-8000-000000000002','a2000000-0000-4000-8000-000000000002','a1000000-0000-4000-8000-000000000002');
INSERT INTO app.membership_roles(clinic_id,membership_id,role,scope) VALUES
 ('a2000000-0000-4000-8000-000000000001','a3000000-0000-4000-8000-000000000001','reception','clinic'),
 ('a2000000-0000-4000-8000-000000000002','a3000000-0000-4000-8000-000000000002','reception','clinic');
INSERT INTO app.patients(id,clinic_id,display_name,birth_date,phone) VALUES
 ('a5000000-0000-4000-8000-000000000001','a2000000-0000-4000-8000-000000000001','Paciente fictício recuperado A','1990-01-01','+5511999990101'),
 ('a5000000-0000-4000-8000-000000000002','a2000000-0000-4000-8000-000000000002','Paciente fictício recuperado B','1990-01-01','+5511999990102');
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","session_id":"a4000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
SELECT api.select_clinic('a2000000-0000-4000-8000-000000000001');
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000002","session_id":"a4000000-0000-4000-8000-000000000002","aal":"aal1","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
SELECT api.select_clinic('a2000000-0000-4000-8000-000000000002');
RESET ROLE;
COMMIT;
