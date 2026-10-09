-- Read the records actually recovered, without changing contexts or sequences.
BEGIN;
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000001","session_id":"a4000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE result jsonb; BEGIN
 result:=api.search_patients('a2000000-0000-4000-8000-000000000001','',0,false);
 IF api.current_clinic() IS DISTINCT FROM 'a2000000-0000-4000-8000-000000000001'::uuid
 OR jsonb_array_length(result->'records') <> 1
 OR result->'records'->0->>'id' IS DISTINCT FROM 'a5000000-0000-4000-8000-000000000001'
 OR api.get_patient('a2000000-0000-4000-8000-000000000002','a5000000-0000-4000-8000-000000000002',false) IS NOT NULL
 THEN RAISE EXCEPTION 'Recovered reception A must see only its own recovered patient'; END IF;
END $$;
RESET ROLE;
SELECT set_config('request.jwt.claims','{"sub":"a1000000-0000-4000-8000-000000000002","session_id":"a4000000-0000-4000-8000-000000000002","aal":"aal1","role":"authenticated"}',true);
SET LOCAL ROLE authenticated;
DO $$ DECLARE result jsonb; BEGIN
 result:=api.search_patients('a2000000-0000-4000-8000-000000000002','',0,false);
 IF api.current_clinic() IS DISTINCT FROM 'a2000000-0000-4000-8000-000000000002'::uuid
 OR jsonb_array_length(result->'records') <> 1
 OR result->'records'->0->>'id' IS DISTINCT FROM 'a5000000-0000-4000-8000-000000000002'
 OR api.get_patient('a2000000-0000-4000-8000-000000000001','a5000000-0000-4000-8000-000000000001',false) IS NOT NULL
 THEN RAISE EXCEPTION 'Recovered reception B must see only its own recovered patient'; END IF;
END $$;
RESET ROLE;
ROLLBACK;
