-- Read the records actually recovered, without changing contexts or sequences.
BEGIN;
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","session_id":"a4000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF api.current_clinic() IS DISTINCT FROM 'a2000000-0000-4000-8000-000000000001'::uuid
 OR (SELECT count(*) FROM app.patients) <> 1
 OR NOT EXISTS(SELECT 1 FROM app.patients WHERE id='a5000000-0000-4000-8000-000000000001')
 THEN RAISE EXCEPTION 'Recovered reception A must see only its own recovered patient'; END IF;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000002","session_id":"a4000000-0000-4000-8000-000000000002","aal":"aal1","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
DO $$ BEGIN
 IF api.current_clinic() IS DISTINCT FROM 'a2000000-0000-4000-8000-000000000002'::uuid
 OR (SELECT count(*) FROM app.patients) <> 1
 OR NOT EXISTS(SELECT 1 FROM app.patients WHERE id='a5000000-0000-4000-8000-000000000002')
 THEN RAISE EXCEPTION 'Recovered reception B must see only its own recovered patient'; END IF;
END $$;
RESET ROLE;
ROLLBACK;
