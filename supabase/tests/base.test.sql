Warning: truncated output (original token count: 33169)
Total output lines: 1006

begin;
create extension if not exists pgtap with schema extensions;
set search_path = public, extensions;
select plan(1);
-- Disposable synthetic identities; never run this on a remote database.
insert into auth.users(id, email) values
('10000000-0000-4000-8000-000000000001', 'fixture1@example.invalid'),
('10000000-0000-4000-8000-000000000002', 'fixture2@example.invalid'),
('10000000-0000-4000-8000-000000000003', 'fixture3@example.invalid'),
('10000000-0000-4000-8000-000000000004', 'fixture4@example.invalid'),
('10000000-0000-4000-8000-000000000005', 'fixture5@example.invalid'),
('10000000-0000-4000-8000-000000000006', 'fixture6@example.invalid'),
('10000000-0000-4000-8000-000000000007', 'fixture7@example.invalid');
insert into auth.sessions(id, user_id, not_after) values
('40000000-0000-4000-8000-000000000001', '10000000-0000-4000-8000-000000000001', now() + interval '1 day'),
('40000000-0000-4000-8000-000000000002', '10000000-0000-4000-8000-000000000002', now() + interval '1 day'),
('40000000-0000-4000-8000-000000000003', '10000000-0000-4000-8000-000000000003', now() + interval '1 day'),
('40000000-0000-4000-8000-000000000004', '10000000-0000-4000-8000-000000000004', now() + interval '1 day'),
('40000000-0000-4000-8000-000000000005', '10000000-0000-4000-8000-000000000005', now() + interval '1 day'),
('40000000-0000-4000-8000-000000000006', '10000000-0000-4000-8000-000000000006', now() + interval '1 day'),
('40000000-0000-4000-8000-000000000007', '10000000-0000-4000-8000-000000000007', now() + interval '1 day'),
('40000000-0000-4000-8000-000000000008', '10000000-0000-4000-8000-000000000005', now() + interval '1 day');
insert into app.users(id, display_name, is_dev) values
('10000000-0000-4000-8000-000000000001','Recepção A',false), ('10000000-0000-4000-8000-000000000002','Recepção B',false),
('10000000-0000-4000-8000-000000000003','Administrador A',false), ('10000000-0000-4000-8000-000000000004','Médico A',false),
('10000000-0000-4000-8000-000000000005','Dev fictício',true), ('10000000-0000-4000-8000-000000000006','Recepção A e B',false),
('10000000-0000-4000-8000-000000000007','Conta inativa',false);
update app.users set active=false where id='10000000-0000-4000-8000-000000000007';
insert into app.clinics(id,name) values ('20000000-0000-4000-8000-000000000001','Clínica fictícia A'),('20000000-0000-4000-8000-000000000002','Clínica fictícia B');
insert into app.memberships(id,clinic_id,user_id) values
('30000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001'),('30000000-0000-4000-8000-000000000002','20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000002'),
('30000000-0000-4000-8000-000000000003','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003'),('30000000-0000-4000-8000-000000000004','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000004'),
('30000000-0000-4000-8000-000000000005','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000006'),('30000000-0000-4000-8000-000000000006','20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000006'),
('30000000-0000-4000-8000-000000000007','20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000007');
insert into app.membership_roles(clinic_id,membership_id,role,scope) values
('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','reception','clinic'),
('20000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000002','reception','clinic'),
('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000003','administrator','clinic'),
('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000004','doctor','own'),
('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000004','reception','own'),
('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000005','reception','clinic'),
('20000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000006','reception','clinic'),
('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000007','reception','clinic');


create function pg_temp.assert_true(condition boolean, label text) returns void
language plpgsql as $$
begin
  if condition is distinct from true then raise exception 'FAILED: %', label; end if;
end;
$$;
create function pg_temp.assert_error(statement text, expected_code text, label text) returns void
language plpgsql as $$
declare actual text;
begin
  begin
    execute statement;
  exception when others then
    get stacked diagnostics actual = returned_sqlstate;
  end;
  if actual is distinct from expected_code then
    raise exception 'FAILED: %, expected %, got %', label, expected_code, actual;
  end if;
end;
$$;
-- Test-only helpers must be callable after SET ROLE; no production grants.
grant execute on function pg_temp.assert_true(boolean,text), pg_temp.assert_error(text,text,text) to anon, authenticated;
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","session_id":"40000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select pg_temp.assert_true((select count(*)=1 from app.clinics), 'Recepção A vê só A');
select pg_temp.assert_true((select count(*)=1 from api.list_clinics()), 'Diretório RPC aplica RLS');
select pg_temp.assert_true((select count(*)=1 from app.users), 'Usuário vê só perfil próprio');
select pg_temp.assert_true((select api.current_clinic() is null), 'Sem seleção não há contexto');
select pg_temp.assert_true((select api.session_profile()->>'id'='10000000-0000-4000-8000-000000000001'), 'RPC retorna apenas perfil próprio');
select pg_temp.assert_true((select (api.session_profile()->>'is_dev')::boolean=false), 'Metadata não eleva perfil web');
select pg_temp.assert_true((select api.workspace() is null), 'Workspace exige seleção');
select pg_temp.assert_error($test$select api.select_clinic('20000000-0000-4000-8000-000000000002')$test$, '42501', 'Clínica não autorizada negada');
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_true((select api.current_clinic()='20000000-0000-4000-8000-000000000001'::uuid), 'Contexto A escolhido');
select pg_temp.assert_true((select api.workspace()->>'id'='20000000-0000-4000-8000-000000000001'), 'Workspace contém apenas clínica selecionada');
select pg_temp.assert_true((select api.workspace()->'roles'='[{"role":"reception","scope":"clinic"}]'::jsonb), 'Workspace retorna papel e escopo atuais');
select pg_temp.assert_true((select count(*)=1 from app.memberships), 'Recepção não lê colegas');
select pg_temp.assert_true((select count(*)=0 from audit.events), 'Recepção não lê auditoria');
select pg_temp.assert_error($test$update app.users set is_dev=true$test$, '42501', 'Autoelevação Dev negada');
select pg_temp.assert_error($test$insert into app.membership_roles values ('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000001','administrator','clinic')$test$, '42501', 'Concessão de função negada');
select pg_temp.assert_error($test$select * from private.clinic_contexts$test$, '42501', 'Contexto privado não legível');
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","session_id":"40000000-0000-4000-8000-000000000002","aal":"aal1","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select pg_temp.assert_true((select api.current_clinic() is null), 'Sessão B não herda seleção A');
select pg_temp.assert_true((select count(*)=1 from app.clinics), 'Recepção B vê só B');
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal1","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select pg_temp.assert_error($test$select api.select_clinic('20000000-0000-4000-8000-000000000001')$test$, '42501', 'Administrador precisa MFA');
select pg_temp.assert_true((select (api.session_profile()->>'requires_mfa')::boolean), 'Administrador pode descobrir exigência MFA em aal1');
select pg_temp.assert_true((select api.workspace() is null), 'Administrador sem MFA não acessa workspace');
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal2","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_true((select count(*)=5 from app.memberships), 'Administrador vê vínculos só da clínica A');
select pg_temp.assert_true((select count(*)=2 from audit.events), 'Administrador lê auditoria de A');
select pg_temp.assert_error($test$delete from audit.events$test$, '42501', 'Auditoria não pode ser apagada');
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005","session_id":"40000000-0000-4000-8000-000000000005","aal":"aal1","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select pg_temp.assert_error($test$select api.select_clinic('20000000-0000-4000-8000-000000000001')$test$, '42501', 'Dev precisa MFA');
select pg_temp.assert_true((select (api.session_profile()->>'requires_mfa')::boolean), 'Dev pode descobrir exigência MFA em aal1');
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005","session_id":"40000000-0000-4000-8000-000000000005","aal":"aal2","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select pg_temp.assert_true((select count(*)=2 from app.clinics), 'Dev vê diretório global');
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_true((select count(*)=3 from audit.events), 'Dev lê auditoria só da clínica selecionada');
select pg_temp.assert_true((select not private.is_clinic_administrator('20000000-0000-4000-8000-000000000001')), 'Dev isolado não é administrador');
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005","session_id":"40000000-0000-4000-8000-000000000008","aal":"aal2","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select pg_temp.assert_true((select api.current_clinic() is null), 'Outra sessão do Dev exige seleção própria');
select api.select_clinic('20000000-0000-4000-8000-000000000002');
select pg_temp.assert_true((select count(*)=1 from audit.events), 'Dev na clínica B não vê logs de A');
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005","session_id":"40000000-0000-4000-8000-000000000005","aal":"aal2","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select pg_temp.assert_true((select api.current_clinic()='20000000-0000-4000-8000-000000000001'::uuid), 'Seleção isolada por sessão');
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000006","session_id":"40000000-0000-4000-8000-000000000006","aal":"aal1","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select api.select_clinic('20000000-0000-4000-8000-000000000002');
select pg_temp.assert_true((select api.current_clinic()='20000000-0000-4000-8000-000000000002'::uuid), 'Troca de clínica na mesma conexão');
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","session_id":"40000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select pg_temp.assert_true((select api.current_clinic()='20000000-0000-4000-8000-000000000001'::uuid), 'Conexão reutilizada não vaza contexto de usuário');
reset role;
update app.memberships set active=false where id='30000000-0000-4000-8000-000000000001';
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000001","session_id":"40000000-0000-4000-8000-000000000001","aal":"aal1","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select pg_temp.assert_true((select api.current_clinic() is null), 'Vínculo revogado invalida contexto com JWT antigo');
select pg_temp.assert_true((select api.workspace() is null), 'Revogação invalida workspace com JWT antigo');
select pg_temp.assert_error($test$select api.select_clinic('20000000-0000-4000-8000-000000000001')$test$, '42501', 'Revogação impede nova seleção');
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000007","session_id":"40000000-0000-4000-8000-000000000007","aal":"aal1","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select pg_temp.assert_true((select count(*)=0 from app.clinics), 'Conta inativa não acessa clínica');
select pg_temp.assert_true((select api.session_profile() is null), 'Conta inativa não recebe perfil web');
reset role;
delete from auth.sessions where id='40000000-0000-4000-8000-000000000002';
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000002","session_id":"40000000-0000-4000-8000-000000000002","aal":"aal1","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select pg_temp.assert_true((select count(*)=0 from app.clinics), 'Sessão removida invalida JWT antigo');
reset role;
update auth.sessions set not_after=now()-interval '1 minute' where id='40000000-0000-4000-8000-000000000004';
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000004","session_id":"40000000-0000-4000-8000-000000000004","aal":"aal1","role":"authenticated","user_metadata":{"is_dev":true}}', true);
set local role authenticated;
select pg_temp.assert_true((select count(*)=0 from app.clinics), 'Sessão expirada não acessa clínica');
reset role;
select set_config('request.jwt.claims', '{"sub":"10000000-0000-4000-8000-000000000005","session_id":"invalid","aal":"aal2"}', true);
set local role authenticated;
select pg_temp.assert_true((select count(*)=0 from api.list_clinics()), 'Sessão malformada falha fechada');
reset role;
select pg_temp.assert_error($test$insert into app.membership_roles values ('20000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000004','doctor','own')$test$, '23503', 'FK composta impede relação entre clínicas');
select pg_temp.assert_error($test$insert into app.memberships(clinic_id,user_id) values ('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003')$test$, '23505', 'Vínculo duplicado bloqueado');
select pg_temp.assert_error($test$insert into app.clinics(name,timezone) values ('Inválida','Fake/Zone')$test$, '23514', 'Fuso inválido bloqueado');
set local role anon;
select pg_temp.assert_error($test$select * from app.clinics$test$, '42501', 'Anônimo sem acesso a tabelas');
select pg_temp.assert_error($test$select api.session_profile()$test$, '42501', 'Anônimo não acessa perfil web');
select pg_temp.assert_error($test$select api.workspace()$test$, '42501', 'Anônimo não acessa workspace');
select pg_temp.assert_error($test$select api.select_clinic('20000000-0000-4000-8000-000000000001')$test$, '42501', 'Anônimo sem acesso a RPC');
reset role;
select pg_temp.assert_true((select bool_and(relrowsecurity) from pg_class c join pg_namespace n on n.oid=c.relnamespace where n.nspname in ('app','private','audit') and c.relkind='r'), 'RLS em todas as tabelas');
select pg_temp.assert_true((select count(*)=0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('api','private') and has_function_privilege('anon',p.oid,'EXECUTE')), 'Nenhuma função acessível ao anônimo');

-- Regression: new public objects must not become accessible without explicit grants.
create table public.exposure_probe(id bigint generated always as identity primary key);
create function public.exposure_probe_rpc() returns integer language sql as $$ select 1; $$;
select pg_temp.assert_true(not has_table_privilege('anon','public.exposure_probe','SELECT'), 'Nova tabela public não exposta ao anônimo');
select pg_temp.assert_true(not has_table_privilege('authenticated','public.exposure_probe','INSERT'), 'Nova tabela public não concede escrita automática');
select pg_temp.assert_true(not has_function_privilege('anon','public.exposure_probe_rpc()','EXECUTE'), 'Nova RPC public não executável por anônimo');
select pg_temp.assert_true(not has_function_privilege('authenticated','public.exposure_probe_rpc()','EXECUTE'), 'Nova RPC public exige grant explícito');

-- Clinic administration: all writes are guarded and audited; no synthetic identities online.
reset role;
insert into auth.users(id,email,email_confirmed_at) values
 ('10000000-0000-4000-8000-000000000008','invited@example.invalid',null),
 ('10000000-0000-4000-8000-000000000009','inactive@example.invalid',now());
insert into app.users(id,display_name,active) values('10000000-0000-4000-8000-000000000009','Inativo',false);
insert into auth.sessions(id,user_id,not_after) values
 ('40000000-0000-4000-8000-000000000009','10000000-0000-4000-8000-000000000008',now()+interval '1 day');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000005","session_id":"40000000-0000-4000-8000-000000000005","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.assert_error($test$select api.create_clinic('Teste','America/Sao_Paulo','50000000-0000-4000-8000-000000000001')$test$,'42501','Criar clínica exige MFA Dev');
reset role;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal2","role":"authenticated","user_metadata":{"is_dev":true}}',true);
set local role authenticated;
select pg_temp.assert_error($test$select api.create_clinic('Teste','America/Sao_Paulo','50000000-0000-4000-8000-000000000001')$test$,'42501','Administrador não cadastra clínica');
select pg_temp.assert_error($test$select * from api.list_administrators()$test$,'42501','Área Dev negada ao administrador');
reset role;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000005","session_id":"40000000-0000-4000-8000-000000000005","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_error($test$select api.create_clinic('Inválida','Fake/Zone','50000000-0000-4000-8000-000000000002')$test$,'23514','Cadastro rejeita fuso inválido');
select set_config('test.created_clinic',api.create_clinic('  Nova clínica  ','America/Sao_Paulo','50000000-0000-4000-8000-000000000001')::text,true);
select pg_temp.assert_true(api.current_clinic()='20000000-0000-4000-8000-000000000001'::uuid,'Cadastro não troca contexto silenciosamente');
select pg_temp.assert_true(api.create_clinic('Nova clínica','America/Sao_Paulo','50000000-0000-4000-8000-000000000001')=current_setting('test.created_clinic')::uuid,'Repetir pedido não duplica clínica');
select pg_temp.assert_error($test$select api.create_clinic('Outra','America/Sao_Paulo','50000000-0000-4000-8000-000000000001')$test$,'42501','Não reutilizar idempotência com outros dados');
select pg_temp.assert_true((select name='Nova clínica' from app.clinics where id=current_setting('test.created_clinic')::uuid),'Nome normalizado no cadastro');
select api.select_clinic(current_setting('test.created_clinic')::uuid);
select pg_temp.assert_true((select count(*)=1 from audit.events where request_id='50000000-0000-4000-8000-000000000001'),'Criação auditada uma única vez');
select pg_temp.assert_true(api.dev_clinic_context(current_setting('test.created_clinic')::uuid)=api.current_clinic(),'Capacidade Dev exige contexto selecionado');
select pg_temp.assert_error($test$select api.administrator_candidate('20000000-0000-4000-8000-000000000001','invited@example.invalid')$test$,'42501','Consulta de candidato exige clínica ativa correta');
select pg_temp.assert_true((api.administrator_candidate(current_setting('test.created_clinic')::uuid,'invited@example.invalid')->>'confirmed')::boolean=false,'Convite pendente identificado sem expor token');
select pg_temp.assert_error($test$select api.administrator_candidate(current_setting('test.created_clinic')::uuid,'inactive@example.invalid')$test$,'42501','Conta inativa não é reativada por cadastro');
select pg_temp.assert_error($test$select api.link_administrator(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000008','wrong@example.invalid','Novo','50000000-0000-4000-8000-000000000003')$test$,'42501','Email e identidade devem corresponder');
select pg_temp.assert_error($test$select api.link_administrator('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000008','invited@example.invalid','Novo','50000000-0000-4000-8000-000000000003')$test$,'42501','Vínculo em outra clínica recusado');
select api.link_administrator(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000008','invited@example.invalid','  Novo administrador  ','50000000-0000-4000-8000-000000000003');
select api.link_administrator(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000008','invited@example.invalid','Novo administrador','50000000-0000-4000-8000-000000000003');
select pg_temp.assert_true((select count(*)=1 from api.list_administrators()),'Administrador listado somente na clínica ativa');
select pg_temp.assert_true((select display_name='Novo administrador' and not confirmed from api.list_administrators()),'Nome e aceite pendente refletidos');
select pg_temp.assert_true((select count(*)=1 from audit.events where request_id='50000000-0000-4000-8000-000000000003' and target_user_id='10000000-0000-4000-8000-000000000008'),'Vínculo e auditoria sem duplicidade');
select pg_temp.assert_error($test$select api.link_administrator(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000009','inactive@example.invalid','Inativo','50000000-0000-4000-8000-000000000004')$test$,'42501','Vínculo não reativa perfil inativo');
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_true((select count(*)=0 from api.list_administrators() where id='10000000-0000-4000-8000-000000000008'),'Lista de A não vaza novo administrador de outra clínica');
reset role;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000008","session_id":"40000000-0000-4000-8000-000000000009","aal":"aal1","role":"authenticated","user_metadata":{"is_dev":true}}',true);
set local role authenticated;
select pg_temp.assert_true((api.session_profile()->>'is_dev')::boolean=false,'Provisionamento não concede Dev');
select pg_temp.assert_true((api.session_profile()->>'requires_mfa')::boolean,'Administrador provisionado precisa MFA');
select pg_temp.assert_error($test$select api.select_clinic(current_setting('test.created_clinic')::uuid)$test$,'42501','Novo administrador sem MFA não entra na clínica');
reset role;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000008","session_id":"40000000-0000-4000-8000-000000000009","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select api.select_clinic(current_setting('test.created_clinic')::uuid);
select pg_temp.assert_true(private.is_clinic_administrator(api.current_clinic()),'Novo vínculo concede administração somente na clínica correta');
select pg_temp.assert_true((select count(*)=1 from api.list_clinics()),'Novo administrador não recebe acesso global');
select pg_temp.assert_error($test$select api.link_administrator(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000009','inactive@example.invalid','Inativo','50000000-0000-4000-8000-000000000004')$test$,'42501','Administrador não concede administração');
reset role;
update app.users set is_dev=false where id='10000000-0000-4000-8000-000000000005';
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000005","session_id":"40000000-0000-4000-8000-000000000005","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.assert_error($test$select api.create_clinic('Sem privilégio','America/Sao_Paulo','50000000-0000-4000-8000-000000000005')$test$,'42501','Dev revogado não escreve com JWT antigo');
reset role;
select pg_temp.assert_true((select count(*)=0 from audit.events where request_id in ('50000000-0000-4000-8000-000000000002','50000000-0000-4000-8000-000000000004','50000000-0000-4000-8000-000000000005')),'Falhas não deixam escritas parciais');
select pg_temp.assert_true((select count(*)=0 from app.memberships where user_id='10000000-0000-4000-8000-000000000009'),'Conta inativa não recebeu vínculo parcial');
select pg_temp.assert_true((select count(*)=0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('api','private') and has_function_privilege('anon',p.oid,'EXECUTE')),'Novas funções negadas ao anônimo');
select pg_temp.assert_error($test$insert into audit.events(clinic_id,actor_user_id,action,request_id) values('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000005','clinic.created','50000000-0000-4000-8000-000000000006')$test$,'23514','Identificador de operação exige fingerprint na auditoria');
-- Invitation cancellation: access first, Auth invalidation completion only after token rotation.
reset role;
update app.users set is_dev=true where id='10000000-0000-4000-8000-000000000005';
update auth.users set confirmation_token='synthetic-old-token' where id='10000000-0000-4000-8000-000000000008';
insert into app.memberships(clinic_id,user_id) values('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000008');
insert into app.membership_roles(clinic_id,membership_id,role,scope)
 select clinic_id,id,'administrator','clinic' from app.memberships where clinic_id='20000000-0000-4000-8000-000000000002' and user_id='10000000-0000-4000-8000-000000000008';
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000005","session_id":"40000000-0000-4000-8000-000000000005","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select api.select_clinic(current_setting('test.created_clinic')::uuid);
select pg_temp.assert_error($test$select api.cancel_administrator_invitation('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000008','50000000-0000-4000-8000-000000000007')$test$,'42501','Não cancela convite de outra clínica');
select api.cancel_administrator_invitation(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000008','50000000-0000-4000-8000-000000000007');
select api.cancel_administrator_invitation(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000008','50000000-0000-4000-8000-000000000007');
select pg_temp.assert_true((select cancelled and invalidation_pending from api.list_administrators() where id='10000000-0000-4000-8000-000000000008'),'Cancelamento incompleto aparece na lista');
select pg_temp.assert_error($test$select api.complete_invitation_cancellation(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000008')$test$,'22023','Não declara token invalidado sem rotação');
reset role;
select pg_temp.assert_true((select count(*)=1 from audit.events where action='administrator.invitation_cancelled'),'Repetir cancelamento não duplica auditoria');
select pg_temp.assert_true((select count(*)=0 from app.membership_roles r join app.memberships m on m.id=r.membership_id where m.user_id='10000000-0000-4000-8000-000000000008' and r.clinic_id=current_setting('test.created_clinic')::uuid and r.role='administrator'),'Papel cancelado removido');
select pg_temp.assert_true((select count(*)=1 from app.membership_roles r join app.memberships m on m.id=r.membership_id where m.user_id='10000000-0000-4000-8000-000000000008' and r.clinic_id='20000000-0000-4000-8000-000000000002' and r.role='administrator'),'Vínculo em outra clínica preservado');
update auth.users set confirmation_token='synthetic-new-token' where id='10000000-0000-4000-8000-000000000008';
set local role authenticated;
select api.complete_invitation_cancellation(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000008');
select pg_temp.assert_true((select cancelled and not invalidation_pending from api.list_administrators() where id='10000000-0000-4000-8000-000000000008'),'Cancelamento concluído aparece na lista');
select pg_temp.assert_error($test$select api.link_administrator(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000008','invited@example.invalid','Novo administrador','50000000-0000-4000-8000-000000000003')$test$,'42501','Replay do cadastro antigo não restaura convite');
select api.link_administrator(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000008','invited@example.invalid','Novo administrador','50000000-0000-4000-8000-000000000008');
select pg_temp.assert_true((select not cancelled from api.list_administrators() where id='10000000-0000-4000-8000-000000000008'),'Novo convite explicitamente solicitado remove estado cancelado');
select pg_temp.assert_error($test$select api.cancel_administrator_invitation(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000008','50000000-0000-4000-8000-000000000007')$test$,'42501','Replay do cancelamento antigo não cancela novo convite');
reset role;
update auth.users set email_confirmed_at=now() where id='10000000-0000-4000-8000-000000000008';
set local role authenticated;
select pg_temp.assert_error($test$select api.cancel_administrator_invitation(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000008','50000000-0000-4000-8000-000000000009')$test$,'22023','Conta confirmada não é cancelada');
reset role;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.assert_error($test$select api.cancel_administrator_invitation(current_setting('test.created_clinic')::uuid,'10000000-0000-4000-8000-000000000008','50000000-0000-4000-8000-000000000010')$test$,'42501','Administrador não cancela convite Dev');
reset role;
-- Team provisioning is scoped, audited and never grants privileged roles.
reset role;
update auth.sessions set not_after=now()+interval '1 day' where id='40000000-0000-4000-8000-000000000004';
insert into auth.users(id,email,email_confirmed_at) values
 ('10000000-0000-4000-8000-000000000010','new-doctor@example.invalid',null),
 ('10000000-0000-4000-8000-000000000011','new-reception@example.invalid',now());
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.assert_error($test$select api.team_clinic_context('20000000-0000-4000-8000-000000000001')$test$,'42501','Gestão de equipe exige MFA');
reset role;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.team_clinic_context('20000000-0000-4000-8000-000000000001')=api.current_clinic(),'Administrador gerencia equipe na própria clínica');
select pg_temp.assert_error($test$select api.team_candidate('20000000-0000-4000-8000-000000000002','new-doctor@example.invalid')$test$,'42501','Outra clínica não permite pesquisar conta');
select pg_temp.assert_error($test$select api.link_team_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000010','new-doctor@example.invalid','Médico','administrator',false,null,'60000000-0000-4000-8000-000000000001')$test$,'22023','Equipe não concede administrador');
select pg_temp.assert_error($test$select api.link_team_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000010','new-doctor@example.invalid','Médico','doctor',true,20,'60000000-0000-4000-8000-000000000001')$test$,'22023','Duração fora das opções recusada');
select api.link_team_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000010','new-doctor@example.invalid','Médico novo','doctor',true,45,'60000000-0000-4000-8000-000000000001');
select api.link_team_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000010','new-doctor@example.invalid','Médico novo','doctor',true,45,'60000000-0000-4000-8000-000000000001');
select pg_temp.assert_error($test$select api.link_team_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000010','new-doctor@example.invalid','Médico novo','doctor',true,60,'60000000-0000-4000-8000-000000000001')$test$,'42501','Operação repetida com outros dados recusada');
select pg_temp.assert_true((select duration_minutes=45 and not confirmed from api.list_team() where id='10000000-0000-4000-8000-000000000010'),'Lista mostra duração e convite pendente');
select pg_temp.assert_true((select count(*)=2 and bool_and(scope='own') from app.membership_roles where membership_id=(select id from app.memberships where user_id='10000000-0000-4000-8000-000000000010' and clinic_id=api.current_clinic())),'Médico com recepção somente própria agenda');
select api.link_team_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000011','new-reception@example.invalid','Recepção nova','reception',false,null,'60000000-0000-4000-8000-000000000002');
select pg_temp.assert_true((select count(*)=1 and bool_and(role='reception' and scope='clinic') from app.membership_roles where membership_id=(select id from app.memberships where user_id='10000000-0000-4000-8000-000000000011' and clinic_id=api.current_clinic())),'Recepção comum recebe somente papel de recepção da clínica');
select pg_temp.assert_error($test$select api.link_team_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000009','inactive@example.invalid','Inativo','reception',false,null,'60000000-0000-4000-8000-000000000003')$test$,'42501','Equipe não reativa conta inativa');
select pg_temp.assert_error($test$select api.link_team_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000005','fixture5@example.invalid','Dev','doctor',false,30,'60000000-0000-4000-8000-000000000003')$test$,'42501','Administrador não altera identidade Dev');
select pg_temp.assert_error($test$insert into app.doctor_settings(clinic_id,membership_id,default_duration_minutes) values('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000004',30)$test$,'42501','Escrita direta de duração negada');
-- Adding doctor to an existing reception narrows that same membership only.
select api.link_team_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000011','new-reception@example.invalid','Nome não substitui cadastro global','doctor',false,15,'60000000-0000-4000-8000-000000000004');
select pg_temp.assert_true((select bool_and(scope='own') from app.membership_roles where membership_id=(select id from app.memberships where user_id='10000000-0000-4000-8000-000000000011' and clinic_id=api.current_clinic())),'Conversão para médico restringe recepção existente');
reset role;
select pg_temp.assert_true((select display_name='Recepção nova' and not is_dev from app.users where id='10000000-0000-4000-8000-000000000011'),'Nome global preservado sem elevação Dev');
select pg_temp.assert_true((select count(*)=1 from audit.events where request_id='60000000-0000-4000-8000-000000000001'),'Cadastro repetido não duplica auditoria');
select pg_temp.assert_true((select count(*)=0 from app.membership_roles where clinic_id='20000000-0000-4000-8000-000000000001' and role='administrator' and membership_id in(select id from app.memberships where user_id in('10000000-0000-4000-8000-000000000010','10000000-0000-4000-8000-000000000011'))),'Novas pessoas não recebem administração');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","session_id":"40000000-0000-4000-8000-000000000004","aal":"aal2","role":"authenticated","user_metadata":{"is_dev":true}}',true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_error($test$select api.list_team()$test$,'42501','Médico com recepção não gerencia equipe nem por metadata');
select pg_temp.assert_true((select count(*)=0 from app.doctor_settings),'Médico não lê duração de outros médicos');
reset role;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000005","session_id":"40000000-0000-4000-8000-000000000005","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000002');
select pg_temp.assert_true((select count(*)=0 from api.list_team() where id in('10000000-0000-4000-8000-000000000010','10000000-0000-4000-8000-000000000011')),'Dev lê equipe somente da clínica selecionada');
select api.link_team_member('20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000010','new-doctor@example.invalid','Médico novo','doctor',false,60,'60000000-0000-4000-8000-000000000005');
reset role;
select pg_temp.assert_true((select count(*)=2 from app.doctor_settings d join app.memberships m on m.id=d.membership_id where m.user_id='10000000-0000-4000-8000-000000000010'),'Mesmo médico pode ter configurações por clínica');
select pg_temp.assert_true((select default_duration_minutes=45 from app.doctor_settings where clinic_id='20000000-0000-4000-8000-000000000001' and membership_id=(select id from app.memberships where user_id='10000000-0000-4000-8000-000000000010' and clinic_id='20000000-0000-4000-8000-000000000001')),'Vínculo em outra clínica não altera duração original');
select pg_temp.assert_true((select count(*)=0 from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname in ('api','private') and has_function_privilege('anon',p.oid,'EXECUTE')),'Novas funções de equipe negadas ao anônimo');

-- Administrators enroll themselves as doctors only in their selected clinic.
reset role;
insert into app.memberships(id,clinic_id,user_id) values('30000000-0000-4000-8000-000000000008','20000000-0000-4000-8000-000000000002','10000000-0000-4000-8000-000000000003');
insert into app.membership_roles(clinic_id,membership_id,role,scope) values
 ('20000000-0000-4000-8000-000000000002','30000000-0000-4000-8000-000000000008','administrator','clinic');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_error($test$select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000002',30,'70000000-0000-4000-8000-000000000001')$test$,'42501','Mesmo administrador em duas clínicas deve selecionar o contexto correto');
select pg_temp.assert_error($test$select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000001',20,'70000000-0000-4000-8000-000000000001')$test$,'22023','Autocadastro médico rejeita duração inválida');
select pg_temp.assert_error($test$select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000001',null,'70000000-0000-4000-8000-000000000001')$test$,'22023','Autocadastro médico exige duração');
select pg_temp.assert_error($test$select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000001',30,null)$test$,'22023','Autocadastro médico exige identificador de operação');
select pg_temp.assert_true(api.configure_administrator_doctor('20000000-0000-4000-8000-000000000001',45,'70000000-0000-4000-8000-000000000001')='10000000-0000-4000-8000-000000000003'::uuid,'Autocadastro sempre usa a identidade da sessão');
select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000001',45,'70000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.workspace()->'roles' @> '[{"role":"administrator","scope":"clinic"},{"role":"doctor","scope":"own"}]'::jsonb,'Administrador mantém administração e recebe perfil médico próprio');
select pg_temp.assert_true((select duration_minutes=45 from api.list_team() where id='10000000-0000-4000-8000-000000000003'),'Administrador médico aparece na equipe com duração');
select pg_temp.assert_true((select count(*)=1 from audit.events where request_id='70000000-0000-4000-8000-000000000001' and action='administrator.doctor_configured' and actor_user_id=target_user_id),'Autocadastro auditado uma vez com ator e alvo próprios');
select pg_temp.assert_error($test$select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000001',60,'70000000-0000-4000-8000-000000000001')$test$,'42501','Idempotência não permite alterar duração com pedido antigo');
select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000001',60,'70000000-0000-4000-8000-000000000002');
select pg_temp.assert_true((select default_duration_minutes=60 from app.doctor_settings where membership_id='30000000-0000-4000-8000-000000000003'),'Administrador médico pode atualizar sua duração');
select api.select_clinic('20000000-0000-4000-8000-000000000002');
select pg_temp.assert_true(not (api.workspace()->'roles' @> '[{"role":"doctor"}]'::jsonb),'Outra clínica não recebe função médica implicitamente');
select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000002',15,'70000000-0000-4000-8000-000000000003');
reset role;
select pg_temp.assert_true((select count(*)=2 from app.memberships where user_id='10000000-0000-4000-8000-000000000003'),'Não duplica conta nem vínculo existente');
select pg_temp.assert_true((select default_duration_minutes=60 from app.doctor_settings where membership_id='30000000-0000-4000-8000-000000000003'),'Duração da clínica A preservada ao configurar B');
select pg_temp.assert_true((select default_duration_minutes=15 from app.doctor_settings where membership_id='30000000-0000-4000-8000-000000000008'),'Duração independente na clínica B');
select pg_temp.assert_true((select display_name='Administrador A' and not is_dev from app.users where id='10000000-0000-4000-8000-000000000003'),'Nome global e identidade não alterados');
-- Self-disable preserves historical references and the doctor's other clinic.
insert into app.patients(id,clinic_id,display_name,birth_date,phone) values('56000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000002','Histórico médico fictício','1990-01-01','+5511999990777');
insert into app.patient_doctors(clinic_id,patient_id,membership_id) values('20000000-0000-4000-8000-000000000002','56000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000008');
set local role authenticated;
select pg_temp.assert_error($test$select api.disable_administrator_doctor('20000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000001')$test$,'42501','Desativação não usa outra clínica sem selecioná-la');
select pg_temp.assert_error($test$select api.disable_administrator_doctor('20000000-0000-4000-8000-000000000002',null)$test$,'22023','Desativação exige operação');
select pg_temp.assert_true(api.disable_administrator_doctor('20000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000001')='10000000-0000-4000-8000-000000000003'::uuid,'Desativa apenas o próprio perfil médico');
select api.disable_administrator_doctor('20000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.workspace()->'roles' @> '[{"role":"administrator","scope":"clinic"}]'::jsonb and not (api.workspace()->'roles' @> '[{"role":"doctor"}]'::jsonb),'Mantém administração sem função médica');
select pg_temp.assert_true(api.patient_permissions('20000000-0000-4000-8000-000000000002')->>'doctor_membership' is null,'JWT anterior não mantém função médica');
reset role;
select pg_temp.assert_true((select count(*)=1 from app.patient_doctors where membership_id='30000000-0000-4000-8000-000000000008'),'Vínculo histórico com paciente preservado');
select pg_temp.assert_true((select default_duration_minutes=15 from app.doctor_settings where membership_id='30000000-0000-4000-8000-000000000008'),'Configuração médica preservada');
select pg_temp.assert_true(exists(select 1 from app.membership_roles where membership_id='30000000-0000-4000-8000-000000000003' and role='doctor'),'Função médica da outra clínica preservada');
select pg_temp.assert_true((select count(*)=1 from audit.events where request_id='71000000-0000-4000-8000-000000000001' and action='administrator.doctor_disabled' and actor_user_id=target_user_id),'Desativação auditada uma vez');
set local role authenticated;
select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000002',15,'71000000-0000-4000-8000-000000000002');
select pg_temp.assert_error($test$select api.disable_administrator_doctor('20000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000001')$test$,'42501','Replay antigo não desativa perfil reativado');
select pg_temp.assert_true(api.workspace()->'roles' @> '[{"role":"doctor"}]'::jsonb,'Reativação continua válida após replay recusado');
reset role;
delete from app.patient_doctors where patient_id='56000000-0000-4000-8000-000000000001';
delete from app.patients where id='56000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.assert_error($test$select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000002',30,'70000000-0000-4000-8000-000000000004')$test$,'42501','Autocadastro exige MFA mesmo com perfil médico');
select pg_temp.assert_error($test$select api.disable_administrator_doctor('20000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000003')$test$,'42501','Desativação exige MFA');
reset role;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","session_id":"40000000-0000-4000-8000-000000000004","aal":"aal2","role":"authenticated","user_metadata":{"administrator":true}}',true);
set local role authenticated;
select pg_temp.assert_error($test$select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000001',30,'70000000-0000-4000-8000-000000000004')$test$,'42501','Médico com recepção não pode usar autocadastro administrativo');
select pg_temp.assert_error($test$select api.disable_administrator_doctor('20000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000003')$test$,'42501','Médico sem administração não usa desativação própria administrativa');
reset role;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000006","session_id":"40000000-0000-4000-8000-000000000006","aal":"aal2","role":"authenticated","user_metadata":{"administrator":true}}',true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_error($test$select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000001',30,'70000000-0000-4000-8000-000000000004')$test$,'42501','Recepção não se torna médica pela opção de administrador');
reset role;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000005","session_id":"40000000-0000-4000-8000-000000000005","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.assert_error($test$select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000002',30,'70000000-0000-4000-8000-000000000004')$test$,'42501','Dev não se torna médico por autocadastro de administrador');
select pg_temp.assert_error($test$select api.disable_administrator_doctor('20000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000003')$test$,'42501','Dev não usa desativação administrativa própria');
reset role;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal2","role":"authenticated"}',true);
update app.memberships set active=false where id='30000000-0000-4000-8000-000000000008';
set local role authenticated;
select pg_temp.assert_error($test$select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000002',15,'70000000-0000-4000-8000-000000000003')$test$,'42501','Replay após revogação do vínculo é negado');
select pg_temp.assert_error($test$select api.disable_administrator_doctor('20000000-0000-4000-8000-000000000002','71000000-0000-4000-8000-000000000003')$test$,'42501','Desativação negada com vínculo revogado');
reset role;
update app.memberships set active=true where id='30000000-0000-4000-8000-000000000008';
delete from app.membership_roles where membership_id='30000000-0000-4000-8000-000000000008' and role='administrator';
set local role authenticated;
select pg_temp.assert_error($test$select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000002',15,'70000000-0000-4000-8000-000000000003')$test$,'42501','Perfil médico não substitui autorização administrativa revogada');
reset role;
set local role anon;
select pg_temp.assert_error($test$select api.configure_administrator_doctor('20000000-0000-4000-8000-000000000001',30,'70000000-0000-4000-8000-000000000004')$test$,'42501','Autocadastro administrativo negado ao anônimo');
select pg_temp.assert_error($test$select api.disable_administrator_doctor('20000000-0000-4000-8000-000000000001','71000000-0000-4000-8000-000000000003')$test$,'42501','Desativação negada ao anônimo');
reset role;

-- Patient registry: synthetic data, scoped access, validation and audit.
reset role;
create function pg_temp.patient_save(
 clinic uuid, patient uuid default null, name text default 'Paciente fictício A', birth date default '1990-01-01',
 phone text default '+5511999990001', email text default null, cpf text default null, version integer default null,
 duplicate boolean default false, own boolean default false, operation uuid default gen_random_uuid()) returns jsonb
language sql security invoker as $helper$
 select api.save_patient(clinic,patient,name,birth,phone,email,cpf,version,duplicate,own,operation);
$helper$;
grant execute on function pg_temp.patient_save(uuid,uuid,text,date,text,text,text,integer,boolean,boolean,uuid) to authenticated,anon;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000006","session_id":"40000000-0000-4000-8000-000000000006","aal":"aal1","role":"authenticated","user_metadata":{"is_dev":true}}',true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_true((api.patient_permissions('20000000-0000-4000-8000-000000000001')->>'can_write')::boolean,'Recepção da clínica pode cadastrar e editar pacientes');
select pg_temp.assert_error($test$select api.patient_permissions('20000000-0000-4000-8000-000000000002')$test$,'42501','Permissões de paciente exigem contexto ativo');
select pg_temp.assert_error($test$select pg_temp.patient_save('20000000-0000-4000-8000-000000000002')$test$,'42501','Nem vínculo em duas clínicas permite cadastro no contexto errado');
select pg_temp.assert_error($test$select pg_temp.patient_save('20000000-0000-4000-8000-000000000001',name=>'')$test$,'22023','Paciente exige nome');
select pg_temp.assert_error($test$select pg_temp.patient_save('20000000-0000-4000-8000-000000000001',birth=>null)$test$,'22023','Paciente exige nascimento');
select pg_temp.assert_error(format('select pg_temp.patient_save(%L,birth=>%L::date)','20000000-0000-4000-8000-000000000001',current_date+2),'22023','Nascimento futuro recusado');
select pg_temp.assert_error($test$select pg_temp.patient_save('20000000-0000-4000-8000-000000000001',phone=>'1234')$test$,'22023','Telefone precisa formato internacional');
select pg_temp.assert_error($test$select pg_temp.patient_save('20000000-0000-4000-8000-000000000001',email=>'invalido')$test$,'22023','Email inválido recusado no banco');
select pg_temp.assert_error($test$select pg_temp.patient_save('20000000-0000-4000-8000-000000000001',cpf=>'00000000192')$test$,'22023','CPF com dígito incorreto recusado');
select pg_temp.assert_error($test$select pg_temp.patient_save('20000000-0000-4000-8000-000000000001',cpf=>'11111111111')$test$,'22023','CPF de dígitos repetidos recusado');
select pg_temp.assert_error($test$select pg_temp.patient_save('20000000-0000-4000-8000-000000000001',version=>1)$test$,'22023','Novo paciente não recebe versão de edição');
select set_config('test.patient_a',pg_temp.patient_save('20000000-0000-4000-8000-000000000001',name=>'  Paciente   fictício A  ',email=>'FICTICIO@EXAMPLE.INVALID',cpf=>'00000000191',operation=>'80000000-0000-4000-8000-000000000001')->>'id',true);
select pg_temp.assert_true(pg_temp.patient_save('20000000-0000-4000-8000-000000000001',name=>'Paciente fictício A',email=>'ficticio@example.invalid',cpf=>'00000000191',operation=>'80000000-0000-4000-8000-000000000001')->>'id'=current_setting('test.patient_a'),'Repetição normalizada retorna o mesmo paciente');
select pg_temp.assert_error($test$select pg_temp.patient_save('20000000-0000-4000-8000-000000000001',name=>'Outros dados',operation=>'80000000-0000-4000-8000-000000000001')$test$,'42501','Reutilizar operação com dados diferentes é recusado');
select pg_temp.assert_true(api.get_patient('20000000-0000-4000-8000-000000000001',current_setting('test.patient_a')::uuid,false)->>'display_name'='Paciente fictício A','Nome normalizado persistido');
select pg_temp.assert_true(api.get_patient('20000000-0000-4000-8000-000000000001',current_setting('test.patient_a')::uuid,false)->>'email'='ficticio@example.invalid','Email normalizado persistido');
select pg_temp.assert_true(jsonb_array_length(api.search_patients('20000000-0000-4000-8000-000000000001','ficticio',0,false)->'records')=1,'Busca por nome ignora acentos');
select pg_temp.assert_true(jsonb_array_length(api.search_patients('20000000-0000-4000-8000-000000000001','000.000.001-91',0,false)->'records')=1,'Busca por CPF com pontuação');
select pg_temp.assert_true(api.search_patients('20000000-0000-4000-8000-000000000001','ficticio',0,false)->'records'->0->>'cpf_suffix'='0191','Lista oferece somente sufixo do CPF');
select pg_temp.assert_true(not (api.search_patients('20000000-0000-4000-8000-000000000001','ficticio',0,false)->'records'->0 ? 'cpf'),'Lista não devolve CPF completo');
select pg_temp.assert_error($test$select api.search_patients('20000000-0000-4000-8000-000000000001','ab',0,false)$test$,'22023','Busca curta é recusada');
select pg_temp.assert_error($test$select api.search_patients('20000000-0000-4000-8000-000000000001','',-1,false)$test$,'22023','Página negativa é recusada');
select pg_temp.assert_error($test$select api.search_patients('20000000-0000-4000-8000-000000000001','',0,true)$test$,'22023','Recepção não usa modo próprio médico');
select pg_temp.assert_true(pg_temp.patient_save('20000000-0000-4000-8000-000000000001',name=>'Mesmo CPF',phone=>'+5511999990002',cpf=>'00000000191',duplicate=>true)->>'status'='cpf_duplicate','CPF duplicado na clínica é bloqueado mesmo após confirmação');
select pg_temp.assert_true(pg_temp.patient_save('20000000-0000-4000-8000-000000000001',name=>'Telefone familiar')->>'status'='possible_duplicate','Telefone compartilhado gera alerta');
select pg_temp.assert_true(pg_temp.patient_save('20000000-0000-4000-8000-000000000001',name=>'Paciente fictício A',phone=>'+5511999990002')->>'status'='possible_duplicate','Nome e nascimento iguais geram alerta');
select set_config('test.patient_family',pg_temp.patient_save('20000000-0000-4000-8000-000000000001',name=>'Telefone familiar',duplicate=>true)->>'id',true);
select pg_temp.assert_true(api.get_patient('20000000-0000-4000-8000-000000000001',current_setting('test.patient_family')::uuid,false)->>'phone'='+5511999990001','Confirmação permite contato familiar sem unicidade de telefone');
select pg_temp.assert_true(pg_temp.patient_save('20000000-0000-4000-8000-000000000001',patient=>current_setting('test.patient_a')::uuid,name=>'Paciente alterado A',phone=>'+5511999990003',cpf=>'00000000191',version=>1,operation=>'80000000-0000-4000-8000-000000000002')->>'status'='saved','Recepção edita paciente com versão atual');
select pg_temp.assert_true((api.get_patient('20000000-0000-4000-8000-000000000001',current_setting('test.patient_a')::uuid,false)->>'version')::integer=2,'Edição incrementa versão');
select pg_temp.assert_true(pg_temp.patient_save('20000000-0000-4000-8000-000000000001',patient=>current_setting('test.patient_a')::uuid,name=>'Paciente alterado A',phone=>'+5511999990003',cpf=>'00000000191',version=>1,operation=>'80000000-0000-4000-8000-000000000002')->>'status'='saved','Replay de edição idêntica não repete alteração');
select pg_temp.assert_true(pg_temp.patient_save('20000000-0000-4000-8000-000000000001',patient=>current_setting('test.patient_a')::uuid,name=>'Edição desatualizada',phone=>'+5511999990003',version=>1)->>'status'='conflict','Versão antiga não sobrescreve edição');
select api.select_clinic('20000000-0000-4000-8000-000000000002');
select pg_temp.assert_true(jsonb_array_length(api.search_patients('20000000-0000-4000-8000-000000000002','',0,false)->'records')=0,'Busca de B não revela pacientes de A');
select pg_temp.assert_true(api.get_patient('20000000-0000-4000-8000-000000000002',current_setting('test.patient_a')::uuid,false) is null,'ID de A não é aberto em B');
select pg_temp.assert_error($test$select pg_temp.patient_save('20000000-0000-4000-8000-000000000002',patient=>current_setting('test.patient_a')::uuid,version=>2)$test$,'42501','ID alheio não pode ser editado na clínica ativa');
select set_config('test.patient_b',pg_temp.patient_save('20000000-0000-4000-8000-000000000002',cpf=>'00000000191')->>'id',true);
select pg_temp.assert_true(current_setting('test.patient_b')<>current_setting('test.patient_a'),'Mesmo CPF em outra clínica não compartilha cadastro');
reset role;
select pg_temp.assert_true((select count(*)=1 from audit.events where request_id='80000000-0000-4000-8000-000000000001' and action='patient.created' and target_patient_id=current_setting('test.patient_a')::uuid),'Criação auditada atomicamente uma vez');
select pg_temp.assert_true((select count(*)=1 from audit.events where request_id='80000000-0000-4000-8000-000000000002' and action='patient.updated'),'Edição auditada atomicamente uma vez');
select pg_temp.assert_true((select bool_and(length(request_fingerprint)=64) from audit.events where action in('patient.created','patient.updated')),'Operações de paciente…3169 tokens truncated…000-4000-8000-000000000001','55000000-0000-4000-8000-000000000003','Reviver','1990-01-01','+5511999990503',null,null,2,false,false,'66000000-0000-4000-8000-000000000006')$test$,'42501','Arquivado não pode ser editado');
select pg_temp.assert_true(api.save_patient('20000000-0000-4000-8000-000000000001',null,'Novo CPF arquivado','1980-01-01','+5511999990504',null,'00000000515',null,false,false,'66000000-0000-4000-8000-000000000007')->>'status'='saved','CPF arquivado não bloqueia novo cadastro ativo');
reset role;
select pg_temp.assert_true(not exists(select 1 from app.patients where id='55000000-0000-4000-8000-000000000001'),'Exclusão remove dados cadastrais do banco');
select pg_temp.assert_true(not exists(select 1 from app.patient_doctors where patient_id='55000000-0000-4000-8000-000000000001'),'Exclusão remove vínculos sem consultas');
select pg_temp.assert_true(exists(select 1 from app.patient_references where id='55000000-0000-4000-8000-000000000001'),'Referência opaca de auditoria permanece');
select pg_temp.assert_true((select count(*)=1 from audit.events where target_patient_id='55000000-0000-4000-8000-000000000001' and action='patient.viewed'),'Auditoria anterior não foi alterada');
select pg_temp.assert_true((select count(*)=1 from audit.events where request_id='66000000-0000-4000-8000-000000000003' and action='patient.deleted' and length(request_fingerprint)=64),'Auditoria de exclusão atômica e única');
select pg_temp.assert_true(exists(select 1 from app.patients where id='55000000-0000-4000-8000-000000000003' and archived_at is not null and display_name='Arquivar fictício'),'Arquivamento preserva histórico e dados');
select pg_temp.assert_error($test$select private.retain_patient_for_consultation('20000000-0000-4000-8000-000000000001','55000000-0000-4000-8000-000000000001')$test$,'42501','Consulta futura não vincula paciente já excluído');
select pg_temp.assert_error($test$insert into app.patients(id,clinic_id,display_name,birth_date,phone) values('55000000-0000-4000-8000-000000000001','20000000-0000-4000-8000-000000000001','Reuso','1990-01-01','+5511999990501')$test$,'23505','Id excluído não pode ser reutilizado');
select pg_temp.assert_true(not has_table_privilege('authenticated','app.patient_references','SELECT') and not has_function_privilege('authenticated','private.retain_patient_for_consultation(uuid,uuid)','EXECUTE'),'Retenção e referências não são acessíveis ao cliente');
insert into app.membership_roles(clinic_id,membership_id,role,scope) values('20000000-0000-4000-8000-000000000001','30000000-0000-4000-8000-000000000004','reception','own') on conflict do nothing;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000004","session_id":"40000000-0000-4000-8000-000000000004","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_true((api.patient_permissions('20000000-0000-4000-8000-000000000001')->>'can_write')::boolean,'Médico com recepção mantém escrita própria');
select pg_temp.assert_error($test$select api.delete_patient('20000000-0000-4000-8000-000000000001',current_setting('test.patient_a')::uuid,1,'66000000-0000-4000-8000-000000000008')$test$,'42501','Médico com recepção própria não exclui pacientes');
select pg_temp.assert_error($test$select api.remove_clinic_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000001','team',1,'66000000-0000-4000-8000-000000000009')$test$,'42501','Médico não remove equipe');
reset role;
update app.memberships set active=true where user_id='10000000-0000-4000-8000-000000000006';
insert into auth.sessions(id,user_id,not_after) values('40000000-0000-4000-8000-000000000006','10000000-0000-4000-8000-000000000006',now()+interval '1 day');
select set_config('test.remove_version',(select access_version::text from app.memberships where id='30000000-0000-4000-8000-000000000005'),true);
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.assert_error($test$select api.remove_clinic_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000006','team',1,'66000000-0000-4000-8000-000000000021')$test$,'42501','Administrador sem MFA não remove equipe');
reset role;
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.remove_clinic_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003','team',1,'66000000-0000-4000-8000-000000000010')->>'status'='self','Não remove próprio acesso');
select pg_temp.assert_error($test$select api.remove_clinic_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000002','team',1,'66000000-0000-4000-8000-000000000011')$test$,'42501','Não remove vínculo de outra clínica');
select pg_temp.assert_error($test$select api.remove_clinic_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003','administrator',1,'66000000-0000-4000-8000-000000000012')$test$,'42501','Administrador não remove administrador');
select pg_temp.assert_true(api.remove_clinic_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000006','team',999,'66000000-0000-4000-8000-000000000013')->>'status'='conflict','Remoção exige versão atual do vínculo');
select pg_temp.assert_true(api.remove_clinic_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000006','team',current_setting('test.remove_version')::integer,'66000000-0000-4000-8000-000000000014')->>'status'='removed','Administrador remove recepção da clínica');
select pg_temp.assert_true(api.remove_clinic_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000006','team',current_setting('test.remove_version')::integer,'66000000-0000-4000-8000-000000000014')->>'status'='removed','Remoção da equipe é idempotente');
reset role;
select pg_temp.assert_true((select not active from app.memberships where id='30000000-0000-4000-8000-000000000005') and (select active from app.memberships where id='30000000-0000-4000-8000-000000000006'),'Outro vínculo continua ativo');
select pg_temp.assert_true((select active from app.users where id='10000000-0000-4000-8000-000000000006') and exists(select 1 from auth.sessions where id='40000000-0000-4000-8000-000000000006'),'Conta e sessão global são preservadas');
select pg_temp.assert_true((select count(*)=1 from audit.events where request_id='66000000-0000-4000-8000-000000000014' and action='team.removed'),'Remoção é auditada uma vez');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000006","session_id":"40000000-0000-4000-8000-000000000006","aal":"aal1","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.assert_error($test$select api.select_clinic('20000000-0000-4000-8000-000000000001')$test$,'42501','JWT antigo não recupera clínica removida');
select api.select_clinic('20000000-0000-4000-8000-000000000002');
select pg_temp.assert_true(api.search_patients('20000000-0000-4000-8000-000000000002','Outra clínica fictícia',0,false)->'records'->0->>'id'='55000000-0000-4000-8000-000000000002','Removido em A continua atendendo em B');
reset role;
update app.memberships set active=true where id='30000000-0000-4000-8000-000000000005';
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.remove_clinic_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000006','team',current_setting('test.remove_version')::integer,'66000000-0000-4000-8000-000000000014')->>'status'='conflict','Replay não remove vínculo restaurado posteriormente');
reset role;
select pg_temp.assert_true((select active from app.memberships where id='30000000-0000-4000-8000-000000000005'),'Vínculo restaurado continua ativo');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000005","session_id":"40000000-0000-4000-8000-000000000005","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select api.select_clinic('20000000-0000-4000-8000-000000000001');
select pg_temp.assert_error($test$select api.delete_patient('20000000-0000-4000-8000-000000000001',current_setting('test.patient_a')::uuid,1,'66000000-0000-4000-8000-000000000015')$test$,'42501','Dev não recebe exclusão operacional de pacientes');
select pg_temp.assert_error($test$select api.remove_clinic_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000006','team',1,'66000000-0000-4000-8000-000000000016')$test$,'42501','Dev isolado não recebe remoção de médicos e recepção');
select pg_temp.assert_true(api.remove_clinic_member('20000000-0000-4000-8000-000000000001','10000000-0000-4000-8000-000000000003','administrator',1,'66000000-0000-4000-8000-000000000017')->>'status'='removed','Dev remove administrador da clínica selecionada');
reset role;
select pg_temp.assert_true((select not active from app.memberships where id='30000000-0000-4000-8000-000000000003'),'Todas as funções do vínculo administrativo ficam sem acesso');
select pg_temp.assert_true((select count(*)>=2 from app.membership_roles where membership_id='30000000-0000-4000-8000-000000000003'),'Funções históricas são preservadas');
select set_config('request.jwt.claims','{"sub":"10000000-0000-4000-8000-000000000003","session_id":"40000000-0000-4000-8000-000000000003","aal":"aal2","role":"authenticated"}',true);
set local role authenticated;
select pg_temp.assert_error($test$select api.search_patients('20000000-0000-4000-8000-000000000001','',0,false)$test$,'42501','Administrador removido perde acesso com JWT antigo');
reset role;
set local role anon;
select pg_temp.assert_error($test$select api.delete_patient('20000000-0000-4000-8000-000000000001',null,1,null)$test$,'42501','Anônimo não exclui pacientes');
select pg_temp.assert_error($test$select api.remove_clinic_member('20000000-0000-4000-8000-000000000001',null,'team',1,null)$test$,'42501','Anônimo não remove usuários');
reset role;

-- Separate synthetic clinics and identities; executed only inside a disposable test transaction.
reset role;
insert into auth.users(id,email) select ('19000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'agenda'||i||'@example.invalid' from generate_series(1,6)i;
insert into auth.sessions(id,user_id,not_after) select ('49000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,('19000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,now()+interval '1 day' from generate_series(1,6)i;
insert into app.users(id,display_name,is_dev) select ('19000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,'Agenda fictícia '||i,i=6 from generate_series(1,6)i;
insert into app.clinics(id,name) values('29000000-0000-4000-8000-000000000001','Agenda fictícia A'),('29000000-0000-4000-8000-000000000002','Agenda fictícia B');
insert into app.memberships(id,clinic_id,user_id) values
 ('39000000-0000-4000-8000-000000000001','29000000-0000-4000-8000-000000000001','19000000-0000-4000-8000-000000000001'),
 ('39000000-0000-4000-8000-000000000002','29000000-0000-4000-8000-000000000002','19000000-0000-4000-8000-000000000002'),
 ('39000000-0000-4000-8000-000000000003','29000000-0000-4000-8000-000000000001','19000000-0000-4000-8000-000000000003'),
 ('39000000-0000-4000-8000-000000000004','29000000-0000-4000-8000-000000000002','19000000-0000-4000-8000-000000000003'),
 ('39000000-0000-4000-8000-000000000005','29000000-0000-4000-8000-000000000001','19000000-0000-4000-8000-000000000004'),
 ('39000000-0000-4000-8000-000000000006','29000000-0000-4000-8000-000000000001','19000000-0000-4000-8000-000000000005');
insert into app.membership_roles(clinic_id,membership_id,role,scope) select clinic_id,id,case when user_id in('19000000-0000-4000-8000-000000000003','19000000-0000-4000-8000-000000000004') then 'doctor' when user_id='19000000-0000-4000-8000-000000000005' then 'administrator' else 'reception' end,case when user_id in('19000000-0000-4000-8000-000000000003','19000000-0000-4000-8000-000000000004') then 'own' else 'clinic' end from app.memberships where clinic_id::text like '29000000%';
insert into app.membership_roles values('29000000-0000-4000-8000-000000000001','39000000-0000-4000-8000-000000000003','reception','own'),('29000000-0000-4000-8000-000000000002','39000000-0000-4000-8000-000000000004','reception','own');
insert into app.doctor_settings select clinic_id,membership_id,30 from app.membership_roles where clinic_id::text like '29000000%' and role='doctor';
insert into app.availability_windows(clinic_id,membership_id,weekday,starts_at,ends_at) select clinic_id,membership_id,i,'08:00','18:00' from app.membership_roles cross join generate_series(0,6)i where clinic_id::text like '29000000%' and role='doctor';
insert into app.patients(id,clinic_id,display_name,birth_date,phone) select ('59000000-0000-4000-8000-'||lpad(i::text,12,'0'))::uuid,case when i=3 then '29000000-0000-4000-8000-000000000002' else '29000000-0000-4000-8000-000000000001' end::uuid,'Paciente agenda fictício '||i,'1990-01-01','+551199999080'||i from generate_series(1,5)i;
insert into app.patient_doctors values('29000000-0000-4000-8000-000000000001','59000000-0000-4000-8000-000000000001','39000000-0000-4000-8000-000000000003'),('29000000-0000-4000-8000-000000000001','59000000-0000-4000-8000-000000000002','39000000-0000-4000-8000-000000000005'),('29000000-0000-4000-8000-000000000002','59000000-0000-4000-8000-000000000003','39000000-0000-4000-8000-000000000004');
select set_config('test.agenda_day',((now() at time zone 'America/Sao_Paulo')::date+7)::text,true);
create function pg_temp.agenda_actor(i integer,clinic text) returns void language plpgsql as $$ begin perform set_config('request.jwt.claims',jsonb_build_object('sub','19000000-0000-4000-8000-'||lpad(i::text,12,'0'),'session_id','49000000-0000-4000-8000-'||lpad(i::text,12,'0'),'role','authenticated','aal',case when i in(5,6) then 'aal2' else 'aal1' end)::text,true); perform api.select_clinic(clinic::uuid); end $$;
create function pg_temp.agenda_save(patient integer,clock_time time,duration integer default 30,appointment uuid default null,version integer default null,replacement uuid default null,replacement_version integer default null,operation uuid default gen_random_uuid()) returns jsonb language sql as $$
 select api.save_appointment(api.current_clinic(),case when api.current_clinic()='29000000-0000-4000-8000-000000000001'::uuid then '39000000-0000-4000-8000-000000000003' else '39000000-0000-4000-8000-000000000004' end::uuid,('59000000-0000-4000-8000-'||lpad(patient::text,12,'0'))::uuid,appointment,current_setting('test.agenda_day')::date+clock_time,duration,version,replacement,replacement_version,false,operation);
$$;
grant execute on function pg_temp.agenda_actor(integer,text),pg_temp.agenda_save(integer,time,integer,uuid,integer,uuid,integer,uuid) to authenticated;
set local role authenticated;
select pg_temp.agenda_actor(1,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(jsonb_array_length(api.agenda_doctors(api.current_clinic(),false))=2,'Recepção lista apenas médicos da própria clínica');
select pg_temp.assert_error($test$select api.agenda_doctors(api.current_clinic(),true)$test$,'42501','Recepção sem médico não abre agenda pessoal');
select pg_temp.assert_true(pg_temp.agenda_save(1,'07:00')->>'status'='unavailable','Agenda exige disponibilidade configurada');
select pg_temp.assert_error($test$select pg_temp.agenda_save(1,'09:00',20)$test$,'22023','Duração inválida recusada');
select pg_temp.assert_error($test$select pg_temp.agenda_save(1,'09:00',45)$test$,'42501','Recepção não escolhe exceção de duração pelo médico');
select pg_temp.assert_error($test$select pg_temp.agenda_save(3,'09:00')$test$,'42501','Paciente de outra clínica não pode ser agendado');
select set_config('test.agenda_first',pg_temp.agenda_save(1,'09:00')->>'id',true);
select pg_temp.assert_true(api.get_appointment(api.current_clinic(),current_setting('test.agenda_first')::uuid,false)->>'status'='agendada','Nova consulta nasce agendada');
select pg_temp.assert_true(pg_temp.agenda_save(1,'09:15')->>'status'='occupied','Consulta agendada impede sobreposição');
select pg_temp.assert_true(api.change_appointment_status(api.current_clinic(),current_setting('test.agenda_first')::uuid,'confirmada',1,false,gen_random_uuid())->>'status'='saved','Confirmação é registrada pela recepção');
select pg_temp.assert_true(pg_temp.agenda_save(1,'09:15')->>'status'='occupied','Confirmação mantém ocupação');
select pg_temp.assert_true(pg_temp.agenda_save(1,'10:00',30,current_setting('test.agenda_first')::uuid,1)->>'status'='conflict','Reagendamento exige versão atual');
select pg_temp.assert_true(pg_temp.agenda_save(1,'10:00',30,current_setting('test.agenda_first')::uuid,2)->>'status'='saved','Reagendamento autorizado');
select pg_temp.assert_true(api.get_appointment(api.current_clinic(),current_setting('test.agenda_first')::uuid,false)->>'status'='agendada','Reagendamento exige nova confirmação');
select pg_temp.assert_true(jsonb_array_length(api.get_appointment(api.current_clinic(),current_setting('test.agenda_first')::uuid,false)->'history')=3,'Horários e estados anteriores preservados');
select pg_temp.assert_true(pg_temp.agenda_save(4,'10:00',30,null,null,current_setting('test.agenda_first')::uuid,2)->>'status'='conflict','Substituição exige versão atual da anterior');
select set_config('test.agenda_replace_op',gen_random_uuid()::text,true);
select set_config('test.agenda_replacement',pg_temp.agenda_save(4,'10:00',30,null,null,current_setting('test.agenda_first')::uuid,3,current_setting('test.agenda_replace_op')::uuid)->>'id',true);
select pg_temp.assert_true(pg_temp.agenda_save(4,'10:00',30,null,null,current_setting('test.agenda_first')::uuid,3,current_setting('test.agenda_replace_op')::uuid)->>'id'=current_setting('test.agenda_replacement'),'Substituição idempotente');
select pg_temp.assert_true(api.get_appointment(api.current_clinic(),current_setting('test.agenda_first')::uuid,false)->>'status'='cancelada','Substituição cancela anterior');
select pg_temp.assert_true(api.change_appointment_status(api.current_clinic(),current_setting('test.agenda_replacement')::uuid,'falta',1,false,gen_random_uuid())->>'status'='too_early','Não registra falta antes do fim');
select pg_temp.assert_true(api.change_agenda_block(api.current_clinic(),'39000000-0000-4000-8000-000000000003',null,current_setting('test.agenda_day')::date+time '10:00',current_setting('test.agenda_day')::date+time '10:15',null,false,gen_random_uuid())->>'status'='occupied','Bloqueio não cobre consulta existente');
select set_config('test.agenda_block',api.change_agenda_block(api.current_clinic(),'39000000-0000-4000-8000-000000000003',null,current_setting('test.agenda_day')::date+time '11:00',current_setting('test.agenda_day')::date+time '12:00',null,false,gen_random_uuid())->>'id',true);
select pg_temp.assert_true(pg_temp.agenda_save(1,'11:00')->>'status'='occupied','Bloqueio impede agendamento');
select pg_temp.assert_true(jsonb_array_length(api.list_agenda(api.current_clinic(),current_setting('test.agenda_day')::date,null,false,0)->'records')=2,'Agenda lista consulta cancelada e substituta');
reset role;
select pg_temp.assert_true((select has_consultation from app.patient_references where id='59000000-0000-4000-8000-000000000004'),'Consulta marca retenção do paciente');
select pg_temp.assert_true(exists(select 1 from app.patient_doctors where patient_id='59000000-0000-4000-8000-000000000004' and membership_id='39000000-0000-4000-8000-000000000003'),'Consulta vincula paciente ao médico atomicamente');
select pg_temp.assert_error($test$insert into private.agenda_occupancy values(gen_random_uuid(),'19000000-0000-4000-8000-000000000003',tstzrange((current_setting('test.agenda_day')::date+time '10:00') at time zone 'America/Sao_Paulo',(current_setting('test.agenda_day')::date+time '10:30') at time zone 'America/Sao_Paulo','[)'))$test$,'23P01','Restrição do banco impede sobreposição mesmo sem pré-consulta');
set local role authenticated;
select pg_temp.agenda_actor(2,'29000000-0000-4000-8000-000000000002');
select pg_temp.assert_true(pg_temp.agenda_save(3,'10:00')='{"status":"occupied"}'::jsonb,'Conflito global não revela origem ou paciente');
select pg_temp.assert_true(pg_temp.agenda_save(3,'11:00')->>'status'='occupied','Bloqueio global também protege outra clínica');
select pg_temp.assert_true(api.get_appointment(api.current_clinic(),current_setting('test.agenda_replacement')::uuid,false) is null,'Consulta de outra clínica não pode ser aberta');
select pg_temp.assert_error($test$select pg_temp.agenda_save(3,'10:00',30,null,null,current_setting('test.agenda_replacement')::uuid,1)$test$,'42501','Substituição não alcança consulta de outra clínica');
select pg_temp.assert_error($test$select api.list_agenda(api.current_clinic(),current_setting('test.agenda_day')::date,'39000000-0000-4000-8000-000000000003',false,0)$test$,'42501','Filtro de médico de outra clínica é recusado');
select pg_temp.agenda_actor(1,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.change_agenda_block(api.current_clinic(),'39000000-0000-4000-8000-000000000003',current_setting('test.agenda_block')::uuid,null,null,1,false,gen_random_uuid())->>'status'='saved','Retirada de bloqueio libera ocupação');
select pg_temp.assert_true(api.change_appointment_status(api.current_clinic(),current_setting('test.agenda_replacement')::uuid,'cancelada',1,false,gen_random_uuid())->>'status'='saved','Cancelamento da equipe libera ocupação');
select pg_temp.assert_true(api.change_appointment_status(api.current_clinic(),current_setting('test.agenda_replacement')::uuid,'confirmada',2,false,gen_random_uuid())->>'status'='conflict','Consulta encerrada não é reaberta');
select pg_temp.agenda_actor(2,'29000000-0000-4000-8000-000000000002');
select pg_temp.assert_true(pg_temp.agenda_save(3,'10:00')->>'status'='saved','Cancelamento em A permite horário em B');
select pg_temp.assert_true(pg_temp.agenda_save(3,'10:30')->>'status'='saved','Consultas adjacentes são permitidas');
select pg_temp.agenda_actor(3,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(jsonb_array_length(api.agenda_doctors(api.current_clinic(),false))=1,'Médico com recepção lista somente próprio médico');
select pg_temp.assert_error($test$select api.agenda_availability(api.current_clinic(),'39000000-0000-4000-8000-000000000005',false)$test$,'42501','Médico com recepção não abre horários do colega');
select pg_temp.assert_error($test$select pg_temp.agenda_save(2,'13:00')$test$,'42501','Médico com recepção não agenda paciente fora do vínculo');
select set_config('test.agenda_own',pg_temp.agenda_save(1,'13:00',45)->>'id',true);
select pg_temp.assert_true(api.get_appointment(api.current_clinic(),current_setting('test.agenda_own')::uuid,true)->>'duration'='45','Médico que agenda escolhe duração excepcional');
select pg_temp.assert_true(api.set_my_consultation_duration(api.current_clinic(),15,gen_random_uuid())->>'status'='saved','Médico pode mudar padrão próprio');
select pg_temp.assert_true(api.get_appointment(api.current_clinic(),current_setting('test.agenda_own')::uuid,true)->>'duration'='45','Mudança do padrão não altera consulta anterior');
select pg_temp.agenda_actor(1,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(pg_temp.agenda_save(1,'14:00',45,current_setting('test.agenda_own')::uuid,1)->>'status'='saved','Recepção preserva duração excepcional ao reagendar');
select pg_temp.assert_true(api.delete_patient(api.current_clinic(),'59000000-0000-4000-8000-000000000004',1,gen_random_uuid())->>'status'='archived','Paciente com consulta real é arquivado');
select pg_temp.assert_true(api.get_appointment(api.current_clinic(),current_setting('test.agenda_replacement')::uuid,false)->>'patient_archived'='true','Histórico continua na agenda após arquivamento');
select pg_temp.assert_error($test$select pg_temp.agenda_save(4,'16:00')$test$,'42501','Não agenda cadastro arquivado');
reset role;
update app.appointments set starts_at=now()-interval '90 minutes',ends_at=now()-interval '45 minutes',duration_minutes=45,version=version+1 where id=current_setting('test.agenda_own')::uuid;
set local role authenticated;
select pg_temp.assert_true(api.change_appointment_status(api.current_clinic(),current_setting('test.agenda_own')::uuid,'concluida',3,false,gen_random_uuid())->>'status'='saved','Conclusão após fim permitida');
select pg_temp.assert_true(api.change_appointment_status(api.current_clinic(),current_setting('test.agenda_own')::uuid,'cancelada',4,false,gen_random_uuid())->>'status'='conflict','Conclusão preserva histórico encerrado');
select pg_temp.agenda_actor(4,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_error($test$select api.change_availability(api.current_clinic(),'39000000-0000-4000-8000-000000000005',null,1,'19:00','20:00',null,true,gen_random_uuid())$test$,'42501','Médico isolado não gerencia atendimento');
select pg_temp.assert_true(api.set_my_consultation_duration(api.current_clinic(),60,gen_random_uuid())->>'status'='saved','Médico isolado pode definir própria duração');
select pg_temp.assert_error($test$select api.change_appointment_status(api.current_clinic(),current_setting('test.agenda_first')::uuid,'confirmada',4,true,gen_random_uuid())$test$,'42501','Médico isolado não registra estado de consulta');
select pg_temp.agenda_actor(5,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.change_availability(api.current_clinic(),'39000000-0000-4000-8000-000000000003',null,1,'19:00','20:00',null,false,gen_random_uuid())->>'status'='saved','Administrador gerencia horários da clínica');
select pg_temp.assert_error($test$select api.change_availability(api.current_clinic(),'39000000-0000-4000-8000-000000000003',null,1,'20:00','19:00',null,false,gen_random_uuid())$test$,'22023','Disponibilidade exige início anterior ao fim');
select pg_temp.assert_true(api.change_availability(api.current_clinic(),'39000000-0000-4000-8000-000000000003',null,1,'19:30','20:30',null,false,gen_random_uuid())->>'status'='occupied','Disponibilidade não duplica intervalos');
select pg_temp.agenda_actor(6,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(jsonb_array_length(api.agenda_doctors(api.current_clinic(),false))=2,'Dev lê agenda da clínica selecionada');
select pg_temp.assert_error($test$select pg_temp.agenda_save(1,'17:00')$test$,'42501','Dev isolado não opera consultas');
select pg_temp.assert_error($test$select * from private.agenda_occupancy$test$,'42501','Projeção global não é legível pelo cliente');
select pg_temp.assert_error($test$update app.appointments set status='cancelada'$test$,'42501','Cliente não altera tabela de consultas');
reset role;
update app.memberships set active=false where id='39000000-0000-4000-8000-000000000001';
select set_config('request.jwt.claims','{"sub":"19000000-0000-4000-8000-000000000001","session_id":"49000000-0000-4000-8000-000000000001","aal":"aal1"}',true);
set local role authenticated;
select pg_temp.assert_error($test$select api.list_agenda('29000000-0000-4000-8000-000000000001',current_setting('test.agenda_day')::date,null,false,0)$test$,'42501','Sessão antiga perde agenda após revogação');
reset role;
set local role anon;
select pg_temp.assert_error($test$select api.agenda_doctors('29000000-0000-4000-8000-000000000001',false)$test$,'42501','Anônimo não lê agenda');
select pg_temp.assert_error($test$select api.save_appointment(null,null,null,null,null,30,null,null,null,false,null)$test$,'42501','Anônimo não agenda');
reset role;

-- Uses the synthetic agenda identities and clinics from agenda.sql; never hosted.
reset role;
grant execute on function pg_temp.assert_true(boolean,text),pg_temp.assert_error(text,text,text) to service_role;
update app.memberships set active=true where id='39000000-0000-4000-8000-000000000001';
select pg_temp.assert_true(private.reminder_plan('2030-04-11 12:00-03','2030-04-09 12:00-03','America/Sao_Paulo')='2030-04-10 08:00-03'::timestamptz,'Lembrete às 8h da véspera no fuso da clínica');
select pg_temp.assert_true(private.reminder_plan('2030-04-11 12:00-03','2030-04-10 13:00-03','America/Sao_Paulo') is null,'Menos de 24h não programa lembrete');
select pg_temp.assert_true(private.reminder_plan('2030-04-11 12:00-03','2030-04-10 09:00-03','America/Sao_Paulo') is null,'Após 8h não programa lembrete tardio mesmo com mais de 24h');
select pg_temp.assert_true(private.reminder_plan('2030-04-11 12:00-03','2030-04-10 08:00-03','America/Sao_Paulo')='2030-04-10 08:00-03'::timestamptz,'Limite de 8h é inclusivo');
select pg_temp.assert_true(private.reminder_plan('2030-04-11 12:00+09','2030-04-09 12:00+09','Asia/Tokyo')='2030-04-10 08:00+09'::timestamptz,'Planejamento respeita outro fuso');
set local role authenticated;
select pg_temp.agenda_actor(1,'29000000-0000-4000-8000-000000000001');
select set_config('test.auto_appt',pg_temp.agenda_save(1,'15:00',15)->>'id',true);
select pg_temp.assert_true(jsonb_array_length(api.list_automations(api.current_clinic(),false,0,current_setting('test.auto_appt')::uuid)->'records')=2,'Consulta e duas tarefas nascem juntas');
select pg_temp.assert_error($test$select api.claim_automation(api.current_clinic(),10)$test$,'42501','Usuário não reserva tarefas do processador');
select pg_temp.assert_error($test$select * from private.automation_tasks$test$,'42501','Fila não possui leitura direta');
select pg_temp.assert_error($test$select private.process_foundation_jobs(25)$test$,'42501','Usuário não dispara processador');
select pg_temp.assert_error($test$select api.list_automations('29000000-0000-4000-8000-000000000002',false,0,null)$test$,'42501','Clínica enviada não concede leitura');
reset role;
-- Isolate current test job from other synthetic agenda operations.
update private.automation_tasks set status='blocked',reason='integration_not_configured',lease_token=null,lease_until=null where appointment_id<>current_setting('test.auto_appt')::uuid and status in('pending','retry','processing');
set local role service_role;
select set_config('test.auto_claim',api.claim_automation('29000000-0000-4000-8000-000000000001',10)::text,true);
select pg_temp.assert_true(jsonb_array_length(current_setting('test.auto_claim')::jsonb)=1,'Só tarefa vencida é reservada; lembrete futuro aguarda');
select pg_temp.assert_true(jsonb_array_length(api.claim_automation('29000000-0000-4000-8000-000000000001',10))=0,'Reserva impede segunda execução');
select pg_temp.assert_error($test$select api.finish_automation('29000000-0000-4000-8000-000000000002',(current_setting('test.auto_claim')::jsonb->0->>'id')::uuid,(current_setting('test.auto_claim')::jsonb->0->>'lease')::uuid,'transient_failure')$test$,'42501','Finalização não cruza clínicas');
select pg_temp.assert_true(api.finish_automation('29000000-0000-4000-8000-000000000001',(current_setting('test.auto_claim')::jsonb->0->>'id')::uuid,gen_random_uuid(),'transient_failure')->>'status'='conflict','Token de reserva incorreto é recusado');
select pg_temp.assert_error($test$select api.finish_automation('29000000-0000-4000-8000-000000000001',(current_setting('test.auto_claim')::jsonb->0->>'id')::uuid,(current_setting('test.auto_claim')::jsonb->0->>'lease')::uuid,'completed')$test$,'22023','Base não permite fingir entrega concluída');
select pg_temp.assert_true(api.finish_automation('29000000-0000-4000-8000-000000000001',(current_setting('test.auto_claim')::jsonb->0->>'id')::uuid,(current_setting('test.auto_claim')::jsonb->0->>'lease')::uuid,'transient_failure')->>'status'='saved','Falha transitória agenda repetição');
select pg_temp.assert_true(api.finish_automation('29000000-0000-4000-8000-000000000001',(current_setting('test.auto_claim')::jsonb->0->>'id')::uuid,(current_setting('test.auto_claim')::jsonb->0->>'lease')::uuid,'transient_failure')->>'status'='already_finished','Finalização repetida não repete efeito');
select pg_temp.assert_true(jsonb_array_length(api.claim_automation('29000000-0000-4000-8000-000000000001',10))=0,'Repetição aguarda intervalo progressivo');
reset role;
select pg_temp.assert_true((select status='retry' and attempts=1 and available_at>=now()+interval '30 seconds' from private.automation_tasks where id=(current_setting('test.auto_claim')::jsonb->0->>'id')::uuid),'Primeira falha usa 30 segundos e preserva tentativa');
update private.automation_tasks set available_at=now()-interval '1 second' where id=(current_setting('test.auto_claim')::jsonb->0->>'id')::uuid;
set local role service_role;
select set_config('test.auto_second',api.claim_automation('29000000-0000-4000-8000-000000000001',10)::text,true);
select pg_temp.assert_true((current_setting('test.auto_second')::jsonb->0->>'lease') is distinct from (current_setting('test.auto_claim')::jsonb->0->>'lease'),'Nova tentativa recebe token novo');
reset role;
update private.automation_tasks set lease_until=now()-interval '1 second' where id=(current_setting('test.auto_second')::jsonb->0->>'id')::uuid;
set local role service_role;
select set_config('test.auto_third',api.claim_automation('29000000-0000-4000-8000-000000000001',10)::text,true);
select pg_temp.assert_true(jsonb_array_length(current_setting('test.auto_third')::jsonb)=1,'Reserva expirada do Google é recuperada');
select pg_temp.assert_true(api.finish_automation('29000000-0000-4000-8000-000000000001',(current_setting('test.auto_third')::jsonb->0->>'id')::uuid,(current_setting('test.auto_third')::jsonb->0->>'lease')::uuid,'integration_not_configured')->>'status'='saved','Integração ausente é registrada sem envio');
reset role;
select pg_temp.assert_true((select status='blocked' and reason='integration_not_configured' and attempts=3 from private.automation_tasks where id=(current_setting('test.auto_third')::jsonb->0->>'id')::uuid),'Ausência de integração não causa loop');
select pg_temp.assert_true((select count(*)=3 from private.automation_attempts where task_id=(current_setting('test.auto_third')::jsonb->0->>'id')::uuid),'Tentativas preservam histórico técnico');
set local role authenticated;
select pg_temp.agenda_actor(1,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.change_appointment_status(api.current_clinic(),current_setting('test.auto_appt')::uuid,'confirmada',1,false,gen_random_uuid())->>'status'='saved','Confirmação atualiza versão e tarefas atomicamente');
reset role;
select pg_temp.assert_true((select count(*)=2 from private.automation_tasks where appointment_id=current_setting('test.auto_appt')::uuid and appointment_version=1 and status='cancelled'),'Versão antiga é invalidada');
select pg_temp.assert_true((select count(*)=2 from private.automation_tasks where appointment_id=current_setting('test.auto_appt')::uuid and appointment_version=2),'Confirmação preserva planejamento do lembrete');
set local role authenticated;
select pg_temp.assert_true(api.change_appointment_status(api.current_clinic(),current_setting('test.auto_appt')::uuid,'cancelada',2,false,gen_random_uuid())->>'status'='saved','Cancelamento mantém tarefa de remover evento');
reset role;
select pg_temp.assert_true((select count(*)=0 from private.automation_tasks where appointment_id=current_setting('test.auto_appt')::uuid and kind='whatsapp_reminder' and status<>'cancelled'),'Cancelamento invalida todos os lembretes');
set local role service_role;
select set_config('test.auto_cancel',api.claim_automation('29000000-0000-4000-8000-000000000001',10)::text,true);
select pg_temp.assert_true(current_setting('test.auto_cancel')::jsonb->0->>'intent'='remove','Cancelamento produz intenção de remover evento');
reset role;
select pg_temp.assert_true(private.process_foundation_jobs(25)>=0,'Processador pode executar sem navegador');
select pg_temp.assert_true(exists(select 1 from private.automation_worker_state where name='foundation'),'Processador grava horário da execução');
-- A running worker loses authority immediately when the appointment is changed.
set local role authenticated;
select pg_temp.agenda_actor(1,'29000000-0000-4000-8000-000000000001');
select set_config('test.auto_new',pg_temp.agenda_save(1,'16:00',15)->>'id',true);
reset role;
update private.automation_tasks set status='blocked',reason='integration_not_configured',lease_token=null,lease_until=null where appointment_id<>current_setting('test.auto_new')::uuid and status in('pending','retry','processing');
set local role service_role;
select set_config('test.auto_running',api.claim_automation('29000000-0000-4000-8000-000000000001',10)::text,true);
set local role authenticated;
select pg_temp.assert_true(api.change_appointment_status(api.current_clinic(),current_setting('test.auto_new')::uuid,'cancelada',1,false,gen_random_uuid())->>'status'='saved','Cancelamento durante reserva é permitido');
set local role service_role;
select pg_temp.assert_true(api.finish_automation('29000000-0000-4000-8000-000000000001',(current_setting('test.auto_running')::jsonb->0->>'id')::uuid,(current_setting('test.auto_running')::jsonb->0->>'lease')::uuid,'integration_not_configured')->>'status'='already_finished','Reserva cancelada não volta a alterar tarefa');
reset role;
select pg_temp.assert_true((select status='cancelled' and lease_token is null from private.automation_tasks where id=(current_setting('test.auto_running')::jsonb->0->>'id')::uuid),'Tarefa antiga permanece cancelada');
set local role authenticated;
select set_config('test.auto_policy',pg_temp.agenda_save(1,'17:00',15)->>'id',true);
reset role;
update private.automation_tasks set status='blocked',reason='integration_not_configured',lease_token=null,lease_until=null where kind='google_sync' and status in('pending','retry','processing');
update private.automation_tasks set due_at=now()-interval '1 minute',available_at=now()-interval '1 minute' where appointment_id=current_setting('test.auto_policy')::uuid and kind='whatsapp_reminder';
set local role service_role;
select set_config('test.auto_wa',api.claim_automation('29000000-0000-4000-8000-000000000001',10)::text,true);
select pg_temp.assert_true(api.finish_automation('29000000-0000-4000-8000-000000000001',(current_setting('test.auto_wa')::jsonb->0->>'id')::uuid,(current_setting('test.auto_wa')::jsonb->0->>'lease')::uuid,'transient_failure')->>'status'='saved','Falha de WhatsApp pode ser registrada');
reset role;
select pg_temp.assert_true((select status='blocked' and reason='retry_policy_pending' from private.automation_tasks where id=(current_setting('test.auto_wa')::jsonb->0->>'id')::uuid),'Não inventa política de repetição de mensagens');
-- Force disposable Google job to its final permitted attempt.
update private.automation_tasks set status='retry',attempts=4,available_at=now()-interval '1 second',reason='transient_failure' where appointment_id=current_setting('test.auto_policy')::uuid and kind='google_sync';
set local role service_role;
select set_config('test.auto_limit',api.claim_automation('29000000-0000-4000-8000-000000000001',10)::text,true);
select pg_temp.assert_true(api.finish_automation('29000000-0000-4000-8000-000000000001',(current_setting('test.auto_limit')::jsonb->0->>'id')::uuid,(current_setting('test.auto_limit')::jsonb->0->>'lease')::uuid,'transient_failure')->>'status'='saved','Última tentativa é encerrada');
reset role;
select pg_temp.assert_true((select status='failed' and reason='attempts_exhausted' and attempts=5 from private.automation_tasks where id=(current_setting('test.auto_limit')::jsonb->0->>'id')::uuid),'Cinco tentativas impedem ciclo infinito');
-- Failure in the outbox must roll back the appointment and its patient references.
alter table private.automation_tasks add constraint test_force_queue_failure check(false) not valid;
set local role authenticated;
select pg_temp.assert_error($test$select pg_temp.agenda_save(1,'17:30',15)$test$,'23514','Falha na tarefa impede gravar consulta parcial');
reset role;
alter table private.automation_tasks drop constraint test_force_queue_failure;
select pg_temp.assert_true(not exists(select 1 from app.appointments where starts_at=(current_setting('test.agenda_day')::date+time '17:30') at time zone 'America/Sao_Paulo'),'Não deixa consulta órfã após falha da fila');
update app.memberships set active=false where id='39000000-0000-4000-8000-000000000003';
update private.automation_tasks set status='pending',attempts=0,reason=null where appointment_id=current_setting('test.auto_policy')::uuid and kind='google_sync';
set local role service_role;
select pg_temp.assert_true(jsonb_array_length(api.claim_automation('29000000-0000-4000-8000-000000000001',10))=0,'Vínculo médico revogado impede reserva de sincronização');
reset role;
select pg_temp.assert_true((select reason='access_revoked' from private.automation_tasks where appointment_id=current_setting('test.auto_policy')::uuid and kind='google_sync'),'Revogação aparece como pendência');
update app.memberships set active=true where id='39000000-0000-4000-8000-000000000003';
set local role authenticated;
select pg_temp.agenda_actor(3,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(not exists(select 1 from jsonb_array_elements(api.list_automations(api.current_clinic(),true,0,null)->'records')t where t->>'doctor'<>'39000000-0000-4000-8000-000000000003'),'Médico lê somente suas tarefas');
select pg_temp.assert_true(not(api.list_automations(api.current_clinic(),true,0,current_setting('test.auto_appt')::uuid)->'records'->0 ? 'lease'),'Leitura do usuário não revela token de reserva');
reset role;
select pg_temp.assert_true(not has_function_privilege('authenticated','api.finish_automation(uuid,uuid,uuid,text)','execute'),'Finalização não é concedida a usuários');
select pg_temp.assert_true(not has_function_privilege('service_role','private.process_foundation_jobs(integer)','execute'),'Chave técnica não recebe processador global');
set local role anon;
select pg_temp.assert_error($test$select api.list_automations(null,false,0,null)$test$,'42501','Anônimo não lê automações');
reset role;

reset role;
set local role authenticated;
select pg_temp.agenda_actor(1,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_error($test$select api.google_status(api.current_clinic())$test$,'42501','Recepção não configura Google de outro médico');
select pg_temp.agenda_actor(6,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_error($test$select api.google_begin(api.current_clinic(),repeat('a',64))$test$,'42501','Dev não conecta agenda como outro médico');
select pg_temp.agenda_actor(3,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.google_status(api.current_clinic())->>'connected'='false','Médico inicia sem conexão');
select pg_temp.assert_error($test$select api.google_begin('29000000-0000-4000-8000-000000000002',repeat('a',64))$test$,'42501','Conexão respeita clínica selecionada');
select pg_temp.assert_error($test$select api.google_begin(api.current_clinic(),'invalid')$test$,'22023','Estado inválido é recusado');
select pg_temp.assert_true(api.google_begin(api.current_clinic(),repeat('a',64))->>'membership'='39000000-0000-4000-8000-000000000003','Estado vincula médico da clínica atual');
select pg_temp.assert_error($test$select api.google_verify(api.current_clinic(),repeat('b',64))$test$,'42501','Estado diferente não autoriza retorno');
select set_config('test.google_proof',api.google_verify(api.current_clinic(),repeat('a',64))->>'proof',true);
select pg_temp.assert_error($test$select api.google_verify(api.current_clinic(),repeat('a',64))$test$,'42501','Retorno não pode ser repetido');
select pg_temp.assert_error($test$select api.google_save(api.current_clinic(),'39000000-0000-4000-8000-000000000003',gen_random_uuid(),repeat('x',80),'calendar','Agenda')$test$,'42501','Usuário não grava credencial técnica');
select pg_temp.assert_error($test$select * from private.google_connections$test$,'42501','Usuário não lê credenciais');
reset role;
set local role service_role;
select pg_temp.assert_error($test$select api.google_save('29000000-0000-4000-8000-000000000002','39000000-0000-4000-8000-000000000004',current_setting('test.google_proof')::uuid,repeat('x',80),'calendar','Agenda')$test$,'42501','Prova não atravessa clínicas');
select pg_temp.assert_true(api.google_save('29000000-0000-4000-8000-000000000001','39000000-0000-4000-8000-000000000003',current_setting('test.google_proof')::uuid,repeat('x',80),'calendar','Agenda teste')->>'status'='saved','Servidor salva conexão validada');
select pg_temp.assert_error($test$select api.google_save('29000000-0000-4000-8000-000000000001','39000000-0000-4000-8000-000000000003',current_setting('test.google_proof')::uuid,repeat('x',80),'calendar','Agenda teste')$test$,'42501','Prova técnica consumida uma vez');
select pg_temp.assert_error($test$select * from private.google_connections$test$,'42501','Nem função técnica tem leitura direta da tabela');
reset role;
set local role authenticated;
select pg_temp.assert_true(api.google_status(api.current_clinic())->>'calendar_name'='Agenda teste','Médico vê somente metadados seguros');
select pg_temp.assert_true(not(api.google_status(api.current_clinic())?'credential'),'Metadados não revelam credenciais');
select pg_temp.assert_error($test$select api.google_begin(api.current_clinic(),repeat('a',64))$test$,'22023','Reconexão exige desconectar explicitamente');
select pg_temp.agenda_actor(4,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.google_status(api.current_clinic())->>'connected'='false','Outro médico não lê vínculo alheio');
select pg_temp.agenda_actor(3,'29000000-0000-4000-8000-000000000002');
select pg_temp.assert_true(api.google_status(api.current_clinic())->>'connected'='false','Mesmo médico possui conexão distinta em outra clínica');
select pg_temp.agenda_actor(3,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.google_disconnect(api.current_clinic())->>'status'='saved','Médico desconecta próprio vínculo');
select pg_temp.assert_true(api.google_status(api.current_clinic())->>'connected'='false','Credencial deixa de existir após desconexão');
select api.google_begin(api.current_clinic(),repeat('c',64));
reset role;
update private.google_oauth_requests set expires_at=now()-interval '1 second';
set local role authenticated;
select pg_temp.assert_error($test$select api.google_verify(api.current_clinic(),repeat('c',64))$test$,'42501','Estado expirado não autoriza conexão');
reset role;
select pg_temp.assert_true((select count(*)=1 from audit.events where action='google.connected'),'Conexão auditada sem segredo');
select pg_temp.assert_true((select count(*)=1 from audit.events where action='google.disconnected'),'Desconexão auditada');
set local role anon;
select pg_temp.assert_error($test$select api.google_status(null)$test$,'42501','Anônimo não acessa conexão');
reset role;

reset role;
select set_config('test.agenda_day',((now() at time zone 'America/Sao_Paulo')::date+60)::text,true);
set local role authenticated;
select pg_temp.agenda_actor(3,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_error($test$select api.google_load_connection(api.current_clinic(),'39000000-0000-4000-8000-000000000003')$test$,'42501','Usuário não recebe credenciais do worker');
select pg_temp.assert_error($test$select api.google_claim_tasks(api.current_clinic(),1)$test$,'42501','Usuário não dispara processamento técnico');
select pg_temp.assert_error($test$select api.google_worker_clinics()$test$,'42501','Usuário não enumera clínicas do worker');
select pg_temp.assert_true(api.google_booking_window(api.current_clinic(),'39000000-0000-4000-8000-000000000003',current_setting('test.agenda_day')::date+time '09:00',30,true)->>'connected'='false','Prévia não conectada retorna apenas metadados');
select pg_temp.assert_error($test$select api.google_booking_window(api.current_clinic(),'39000000-0000-4000-8000-000000000005',current_setting('test.agenda_day')::date+time '09:00',30,true)$test$,'42501','Médico não verifica agenda de outro profissional');
select set_config('test.sync_appointment',pg_temp.agenda_save(1,'09:00')->>'id',true);
reset role;
insert into private.google_connections(clinic_id,membership_id,credential,calendar_id,calendar_name) values('29000000-0000-4000-8000-000000000001','39000000-0000-4000-8000-000000000003',repeat('x',80),'synthetic-calendar','Agenda fictícia');
-- Isolate only this disposable task; no hosted fixtures are used.
update private.automation_tasks set status='blocked',reason='permanent_failure',lease_token=null,lease_until=null where appointment_id<>current_setting('test.sync_appointment')::uuid and status in('pending','retry','processing');
set local role service_role;
select pg_temp.assert_true(api.google_load_connection('29000000-0000-4000-8000-000000000002','39000000-0000-4000-8000-000000000003') is null,'Credencial exige par clínica e médico');
select pg_temp.assert_true(jsonb_array_length(api.claim_automation('29000000-0000-4000-8000-000000000001',1))=0,'Processador antigo não consome Google conectado');
select set_config('test.sync_task',(api.google_claim_tasks('29000000-0000-4000-8000-000000000001',1)->0)::text,true);
select pg_temp.assert_true(jsonb_array_length(api.google_claim_tasks('29000000-0000-4000-8000-000000000001',1))=0,'Worker concorrente não reserva a mesma tarefa');
select pg_temp.assert_true(api.google_task_payload('29000000-0000-4000-8000-000000000001',(current_setting('test.sync_task')::jsonb->>'id')::uuid,gen_random_uuid()) is null,'Token incorreto não libera payload');
select pg_temp.assert_true(not(api.google_task_payload('29000000-0000-4000-8000-000000000001',(current_setting('test.sync_task')::jsonb->>'id')::uuid,(current_setting('test.sync_task')::jsonb->>'lease')::uuid)?'patient'),'Payload técnico não contém paciente');
select pg_temp.assert_true(api.google_finish_task('29000000-0000-4000-8000-000000000001',(current_setting('test.sync_task')::jsonb->>'id')::uuid,(current_setting('test.sync_task')::jsonb->>'lease')::uuid,'google_conflict')->>'status'='saved','Conflito é registrado sem apagar consulta');
reset role;
select pg_temp.assert_true((select status='agendada' from app.appointments where id=current_setting('test.sync_appointment')::uuid),'Consulta preserva status e horário após conflito externo');
select pg_temp.assert_true((select reason='google_conflict' from private.automation_tasks where id=(current_setting('test.sync_task')::jsonb->>'id')::uuid),'Conflito fica visível na tarefa atual');
set local role authenticated;
select pg_temp.agenda_actor(3,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(pg_temp.agenda_save(1,'10:00',30,current_setting('test.sync_appointment')::uuid,1)->>'status'='google_check_required','API direta não ignora verificação Google');
select set_config('test.booking_operation',gen_random_uuid()::text,true);
select set_config('test.booking_proof',api.google_begin_booking(api.current_clinic(),'39000000-0000-4000-8000-000000000003',current_setting('test.agenda_day')::date+time '10:00',30,true,current_setting('test.booking_operation')::uuid)->>'proof',true);
select pg_temp.assert_error($test$select api.google_approve_booking(api.current_clinic(),current_setting('test.booking_proof')::uuid,'free')$test$,'42501','Usuário não declara disponibilidade externa');
reset role;
set local role service_role;
select pg_temp.assert_true(api.google_approve_booking('29000000-0000-4000-8000-000000000002',current_setting('test.booking_proof')::uuid,'free')=false,'Prova não atravessa clínica');
select pg_temp.assert_true(api.google_approve_booking('29000000-0000-4000-8000-000000000001',current_setting('test.booking_proof')::uuid,'unavailable'),'Servidor registra indisponibilidade sem liberar outros horários');
reset role;
set local role authenticated;
select pg_temp.assert_true(pg_temp.agenda_save(1,'10:30',30,current_setting('test.sync_appointment')::uuid,1,null,null,current_setting('test.booking_operation')::uuid)->>'status'='google_check_required','Prova vincula horário e operação');
select pg_temp.assert_true(pg_temp.agenda_save(1,'10:00',30,current_setting('test.sync_appointment')::uuid,1,null,null,current_setting('test.booking_operation')::uuid)->>'status'='saved','Reagendamento com Google indisponível preserva fila e confirmação nova');
reset role;
-- Age cancelled attempts to simulate expiry of the bounded external lease.
update private.automation_attempts set started_at=now()-interval '3 minutes';
set local role service_role;
select set_config('test.sync_task',(api.google_claim_tasks('29000000-0000-4000-8000-000000000001',1)->0)::text,true);
select pg_temp.assert_true(api.google_finish_task('29000000-0000-4000-8000-000000000001',(current_setting('test.sync_task')::jsonb->>'id')::uuid,(current_setting('test.sync_task')::jsonb->>'lease')::uuid,'completed')->>'status'='saved','Somente worker com reserva válida registra sucesso');
select pg_temp.assert_true(api.google_task_payload('29000000-0000-4000-8000-000000000001',(current_setting('test.sync_task')::jsonb->>'id')::uuid,(current_setting('test.sync_task')::jsonb->>'lease')::uuid) is null,'Payload deixa de ser acessível após finalização');
reset role;
select pg_temp.assert_true((select status='completed' and reason is null from private.automation_tasks where id=(current_setting('test.sync_task')::jsonb->>'id')::uuid),'Conclusão salva sem conteúdo externo na fila');
select pg_temp.assert_true(not has_function_privilege('authenticated','private.claim_selected_automation(uuid,integer,text)','execute'),'Reserva interna nunca é API de usuário');

reset role;
insert into app.patients(id,clinic_id,display_name,birth_date,phone) values('59000000-0000-4000-8000-000000000090','29000000-0000-4000-8000-000000000001','WhatsApp fictício','2000-01-01','+12025550190');
select pg_temp.assert_true((select whatsapp_enabled from app.patients where id='59000000-0000-4000-8000-000000000090'),'Telefone cadastrado habilita preferência, não envio');
set local role authenticated;
select pg_temp.agenda_actor(1,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_error($test$select api.whatsapp_channel(api.current_clinic())$test$,'42501','Recepção não lê configuração do canal');
select pg_temp.assert_error($test$select * from private.whatsapp_channels$test$,'42501','Configuração não tem acesso direto');
select pg_temp.assert_true((api.patient_whatsapp(api.current_clinic(),'59000000-0000-4000-8000-000000000090',false)->>'enabled')::boolean,'Recepção vê preferência da própria clínica');
select pg_temp.assert_true(api.set_patient_whatsapp(api.current_clinic(),'59000000-0000-4000-8000-000000000090',1,false,false)->>'status'='saved','Recepção pode desativar preferência');
select pg_temp.assert_true(api.set_patient_whatsapp(api.current_clinic(),'59000000-0000-4000-8000-000000000090',1,true,false)->>'status'='conflict','Edição antiga não reativa preferência');
select pg_temp.assert_true(not (api.patient_whatsapp(api.current_clinic(),'59000000-0000-4000-8000-000000000090',false)->>'enabled')::boolean,'Desativação persistida');
select pg_temp.assert_error($test$select api.patient_whatsapp('29000000-0000-4000-8000-000000000002','59000000-0000-4000-8000-000000000090',false)$test$,'42501','Preferência não atravessa clínicas');
select pg_temp.agenda_actor(3,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_error($test$select api.set_patient_whatsapp(api.current_clinic(),'59000000-0000-4000-8000-000000000090',2,true,true)$test$,'42501','Médico com recepção não altera paciente sem vínculo');
select pg_temp.agenda_actor(5,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.whatsapp_channel(api.current_clinic())->>'status'='unconfigured','Administrador inicia sem canal');
select pg_temp.assert_error($test$select api.configure_whatsapp_channel(api.current_clinic(),0,'invalid',null,null,'draft')$test$,'22023','Canal exige número normalizado');
select pg_temp.assert_error($test$select api.configure_whatsapp_channel(api.current_clinic(),0,'+12025550187',null,null,'active')$test$,'22023','API não oferece ativação');
select pg_temp.assert_true(api.configure_whatsapp_channel(api.current_clinic(),0,'+12025550187','123456','654321','draft')->>'status'='saved','Administrador prepara canal');
select set_config('test.wa_channel',api.whatsapp_channel(api.current_clinic())->>'id',true);
select pg_temp.assert_true(api.configure_whatsapp_channel(api.current_clinic(),0,'+12025550188',null,null,'paused')->>'status'='conflict','Mudança concorrente exige nova versão');
select pg_temp.assert_true(api.configure_whatsapp_channel(api.current_clinic(),1,'+12025550188','123457','654321','paused')->>'status'='saved','Número pode ser substituído sem ativação');
select pg_temp.assert_true(api.whatsapp_channel(api.current_clinic())->>'id'=current_setting('test.wa_channel'),'Identidade interna do canal permanece estável');
select pg_temp.assert_true(not (api.whatsapp_channel(api.current_clinic())->>'sends_enabled')::boolean,'Preparar canal jamais habilita envios');
select pg_temp.assert_error($test$select api.whatsapp_channel('29000000-0000-4000-8000-000000000002')$test$,'42501','Admin não abre canal de outra clínica');
select pg_temp.agenda_actor(6,'29000000-0000-4000-8000-000000000001');
select pg_temp.assert_true(api.whatsapp_channel(api.current_clinic())->>'version'='2','Dev com MFA vê apenas clínica selecionada');
select pg_temp.assert_error($test$select api.set_patient_whatsapp(api.current_clinic(),'59000000-0000-4000-8000-000000000090',2,true,false)$test$,'42501','Dev isolado não edita paciente');
reset role;
select pg_temp.assert_true((select count(*)=2 from private.whatsapp_channel_revisions where clinic_id='29000000-0000-4000-8000-000000000001'),'Histórico preserva ambos os remetentes');
select pg_temp.assert_true((select count(*)=2 from audit.events where action='whatsapp.channel_configured'),'Configurações são auditadas');
select pg_temp.assert_true((select count(*)=1 from audit.events where action='whatsapp.preference_updated'),'Preferência é auditada');
select pg_temp.assert_error($test$update private.whatsapp_channels set sends_enabled=true$test$,'23514','Banco bloqueia ativação até por escrita privilegiada');
set local role service_role;
select pg_temp.assert_error($test$select * from private.whatsapp_channel_revisions$test$,'42501','Credencial técnica não lê histórico diretamente');
select pg_temp.assert_error($test$insert into private.whatsapp_receipts values(null,null,null,repeat('a',64),'synthetic','sent',now(),now())$test$,'42501','Retornos não podem ser gravados nesta etapa');
set local role anon;
select pg_temp.assert_error($test$select api.whatsapp_channel(null)$test$,'42501','Anônimo não acessa canais');
reset role;

select pass('All foundation SQL assertions passed on real Supabase Auth tables');
select * from finish();
rollback;
