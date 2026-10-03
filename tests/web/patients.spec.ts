import {test,expect,type Page} from '@playwright/test';
import {createClient} from '@supabase/supabase-js';
import {randomUUID} from 'node:crypto';
import {fixture,localOnly,sql} from './local';
const f=fixture();localOnly(f.url);
async function login(page:Page,email:string,clinic=f.clinics.a){
 await page.goto('/entrar');await page.getByLabel('Email',{exact:true}).fill(email);await page.getByLabel('Senha',{exact:true}).fill(f.password);await page.getByRole('button',{name:'Entrar',exact:true}).click();
 await expect(page).toHaveURL(/\/clinicas$/);await page.getByLabel('Clínica',{exact:true}).selectOption(clinic);await page.getByRole('button',{name:'Acessar clínica'}).click();await expect(page).toHaveURL(/\/inicio$/);
}
async function api(role:string,clinic=f.clinics.a){
 const client=createClient(f.url,f.key,{db:{schema:'api'},auth:{persistSession:false,autoRefreshToken:false}});
 expect((await client.auth.signInWithPassword({email:f.users[role].email,password:f.password})).error).toBeNull();
 expect((await client.rpc('select_clinic',{clinic_id:clinic})).error).toBeNull();return client;
}
function payload(name:string,phone='+5511999990101'){
 return {clinic_id:f.clinics.a,patient_id:null,display_name:name,birth_date:'1990-01-01',phone,email:null,cpf:null,expected_version:null,allow_duplicate:false,own_only:false,operation_id:randomUUID()};
}
async function fill(page:Page,name:string,phone:string,cpf=''){
 await page.getByLabel('Nome completo',{exact:true}).fill(name);await page.getByLabel('Data de nascimento',{exact:true}).fill('1990-01-01');await page.getByLabel('Telefone / WhatsApp',{exact:true}).fill(phone);await page.getByLabel('CPF (opcional)',{exact:true}).fill(cpf);
}

test('reception registers, searches and edits patients with validation, duplicate warnings and stale-edit protection',async({page,browser})=>{
 test.setTimeout(120000);
 const name='Paciente fictício '+randomUUID(),family='Familiar fictício '+randomUUID();
 await login(page,f.users.receptionA.email);await page.getByRole('link',{name:'Abrir pacientes',exact:true}).click();
 await page.getByRole('link',{name:'Cadastrar paciente',exact:true}).click();
 await fill(page,name,'(11) 99999-0102','000.000.001-92');await page.getByRole('button',{name:'Cadastrar paciente',exact:true}).click();
 await expect(page.getByRole('alert')).toContainText('CPF válido');await expect(page.getByLabel('Nome completo')).toHaveValue(name);
 await page.getByLabel('CPF (opcional)').fill('000.000.001-91');await page.getByRole('button',{name:'Cadastrar paciente',exact:true}).click();
 await expect(page).toHaveURL(/\/pacientes\/[0-9a-f-]{36}\?salvo=1$/);await expect(page.getByRole('status')).toContainText('Cadastro salvo');
 await expect(page.getByLabel('Telefone / WhatsApp')).toHaveValue('+5511999990102');await expect(page.getByLabel('CPF (opcional)')).toHaveValue('00000000191');
 const id=new URL(page.url()).pathname.split('/').at(-1)!;
 await page.getByRole('link',{name:'Voltar aos pacientes'}).click();await page.getByLabel('Nome, telefone, email ou CPF').fill(name);await page.getByRole('button',{name:'Pesquisar',exact:true}).click();
 await expect(page.getByRole('link',{name,exact:true})).toBeVisible();await expect(page).toHaveURL(/\/pacientes$/);expect(page.url()).not.toContain(encodeURIComponent(name));
 await page.getByRole('link',{name:'Cadastrar paciente',exact:true}).click();await fill(page,family,'11999990102');await page.getByRole('button',{name:'Cadastrar paciente',exact:true}).click();
 const duplicate=page.getByRole('region',{name:'Possíveis cadastros duplicados'});await expect(duplicate).toBeVisible();await expect(page.getByLabel('Nome completo')).toHaveValue(family);await expect(page.getByLabel('Telefone / WhatsApp')).toHaveValue('11999990102');
 await page.getByLabel('Nome completo').fill(family+' novo');await expect(duplicate).toHaveCount(0);await page.getByRole('button',{name:'Cadastrar paciente',exact:true}).click();await expect(duplicate).toBeVisible();
 await page.getByLabel('Conferi os cadastros e quero salvar mesmo assim').check();await page.getByRole('button',{name:'Cadastrar paciente',exact:true}).click();await expect(page).toHaveURL(/\/pacientes\/[0-9a-f-]{36}\?salvo=1$/);
 await page.goto('/pacientes/novo');await fill(page,'Outro CPF fictício','11999990103','00000000191');await page.getByRole('button',{name:'Cadastrar paciente',exact:true}).click();await expect(page.getByRole('alert')).toContainText('Já existe um paciente com esse CPF');
 await page.goto('/pacientes/'+id);const secondContext=await browser.newContext(),second=await secondContext.newPage();await login(second,f.users.receptionA.email);await second.goto('/pacientes/'+id);
 await page.getByLabel('Nome completo').fill(name+' atualizado');await page.getByRole('button',{name:'Salvar alterações',exact:true}).click();await expect(page.getByRole('status')).toContainText('Cadastro salvo');
 await second.getByLabel('Nome completo').fill(name+' edição antiga');await second.getByRole('button',{name:'Salvar alterações',exact:true}).click();await expect(second.getByRole('alert')).toContainText('alterado por outra pessoa');await expect(second.getByRole('button',{name:'Salvar alterações'})).toBeDisabled();
 await second.getByRole('link',{name:'Atualizar cadastro',exact:true}).click();await expect(second.getByLabel('Nome completo')).toHaveValue(name+' atualizado');await secondContext.close();
 const a=await api('receptionA'),b=await api('receptionB',f.clinics.b);
 expect((await b.rpc('get_patient',{clinic_id:f.clinics.b,patient_id:id,own_only:false})).data).toBeNull();
 expect((await b.rpc('save_patient',{...payload('Negado'),clinic_id:f.clinics.b,patient_id:id,expected_version:2})).error?.code).toBe('42501');
 expect((await a.rpc('get_patient',{clinic_id:f.clinics.b,patient_id:id,own_only:false})).error?.code).toBe('42501');
});

test('patient API handles simultaneous CPF creation and edits, pagination and anonymous access without leaking other clinics',async({page})=>{
 test.setTimeout(120000);
 const a=await api('receptionA'),name='Concorrência fictícia '+randomUUID(),request={...payload(name,'+5511999990104'),cpf:'00000000353'};
 const created=await Promise.all([a.rpc('save_patient',request),a.rpc('save_patient',{...request,operation_id:randomUUID()})]);
 expect(created.every(r=>!r.error)).toBe(true);expect(created.map(r=>r.data.status).sort()).toEqual(['cpf_duplicate','saved']);
 const id=created.find(r=>r.data.status==='saved')!.data.id;
 const edits=await Promise.all(['edição A','edição B'].map(s=>a.rpc('save_patient',{...request,patient_id:id,display_name:name+' '+s,expected_version:1,operation_id:randomUUID()})));
 expect(edits.every(r=>!r.error)).toBe(true);expect(edits.map(r=>r.data.status).sort()).toEqual(['conflict','saved']);
 expect((await a.rpc('get_patient',{clinic_id:f.clinics.a,patient_id:id,own_only:false})).data.version).toBe(2);
 const anon=createClient(f.url,f.key,{db:{schema:'api'},auth:{persistSession:false,autoRefreshToken:false}});
 expect((await anon.rpc('search_patients',{clinic_id:f.clinics.a,search_term:'',page_number:0,own_only:false})).error).not.toBeNull();
 expect((await anon.rpc('save_patient',payload('Negado'))).error).not.toBeNull();
 const statements=Array.from({length:27},(_,i)=>`insert into app.patients(clinic_id,display_name,birth_date,phone) values('${f.clinics.a}','Paginação fictícia ${String(i).padStart(2,'0')}','1980-01-01','+551199998${String(i).padStart(4,'0')}');`).join('\n');
 sql('do $pagination_fixture$ begin '+statements+' end $pagination_fixture$;');
 await login(page,f.users.receptionA.email);await page.goto('/pacientes');await page.getByLabel('Nome, telefone, email ou CPF').fill('paginacao ficticia');await page.getByRole('button',{name:'Pesquisar',exact:true}).click();
 await expect(page.locator('.patient-list>li')).toHaveCount(25);await expect(page.getByRole('button',{name:'Próxima',exact:true})).toBeEnabled();await page.getByRole('button',{name:'Próxima',exact:true}).click();
 await expect(page.locator('.patient-list>li')).toHaveCount(2);await expect(page.getByRole('button',{name:'Próxima',exact:true})).toBeDisabled();await page.getByRole('button',{name:'Anterior',exact:true}).click();await expect(page.locator('.patient-list>li')).toHaveCount(25);
 const b=await api('receptionB',f.clinics.b);expect((await b.rpc('search_patients',{clinic_id:f.clinics.b,search_term:'paginacao ficticia',page_number:0,own_only:false})).data.records).toEqual([]);
});

test('doctor sees only linked patients; own reception creates self-linked patients while shared records and doctor-only accounts remain read-only',async({page,browser})=>{
 test.setTimeout(120000);
 const reception=await api('receptionA'),doctor=await api('doctor');
 const sharedName='Compartilhado fictício '+randomUUID(),otherName='Alheio fictício '+randomUUID();
 const shared=await reception.rpc('save_patient',payload(sharedName,'+5511999990105'));expect(shared.error).toBeNull();
 const other=await reception.rpc('save_patient',payload(otherName,'+5511999990106'));expect(other.error).toBeNull();
 const admin=createClient(f.url,f.adminKey,{auth:{persistSession:false,autoRefreshToken:false}}),email='readonly-doctor-'+randomUUID()+'@example.invalid';
 const account=await admin.auth.admin.createUser({email,password:f.password,email_confirm:true});expect(account.error).toBeNull();const membership=randomUUID();
 sql(`do $doctor_fixture$ begin
 insert into app.users(id,display_name) values('${account.data.user!.id}','Médico somente consulta');
 insert into app.memberships(id,clinic_id,user_id) values('${membership}','${f.clinics.a}','${account.data.user!.id}');
 insert into app.membership_roles(clinic_id,membership_id,role,scope) values('${f.clinics.a}','${membership}','doctor','own');
 insert into app.patient_doctors(clinic_id,patient_id,membership_id) values('${f.clinics.a}','${shared.data.id}','${membership}');
 insert into app.patient_doctors(clinic_id,patient_id,membership_id) select '${f.clinics.a}','${shared.data.id}',id from app.memberships where clinic_id='${f.clinics.a}' and user_id='${f.users.doctor.id}';
 end $doctor_fixture$;`);
 await login(page,f.users.doctor.email);await page.getByRole('link',{name:'Abrir meus pacientes',exact:true}).click();await expect(page.getByRole('link',{name:sharedName,exact:true})).toBeVisible();await expect(page.getByText(otherName,{exact:true})).toHaveCount(0);
 await page.getByRole('link',{name:sharedName,exact:true}).click();await expect(page.getByRole('button',{name:'Salvar alterações'})).toHaveCount(0);await expect(page.getByText(/Cadastro compartilhado/)).toBeVisible();
 expect((await doctor.rpc('save_patient',{...payload('Negado'),patient_id:shared.data.id,expected_version:1})).error?.code).toBe('42501');
 expect((await doctor.rpc('get_patient',{clinic_id:f.clinics.a,patient_id:other.data.id,own_only:false})).data).toBeNull();
 await page.getByRole('link',{name:'Voltar aos pacientes'}).click();await page.getByRole('link',{name:'Cadastrar paciente',exact:true}).click();const ownName='Próprio fictício '+randomUUID();
 await fill(page,ownName,'11999990107');await page.getByRole('button',{name:'Cadastrar paciente',exact:true}).click();await expect(page).toHaveURL(/\/meus-pacientes\/[0-9a-f-]{36}\?salvo=1$/);
 await expect(page.getByLabel('Nome completo')).toHaveValue(ownName);await page.getByLabel('Email (opcional)').fill('own@example.invalid');await page.getByRole('button',{name:'Salvar alterações'}).click();await expect(page.getByRole('status')).toContainText('Cadastro salvo');
 const readContext=await browser.newContext(),readPage=await readContext.newPage();await login(readPage,email);await readPage.getByRole('link',{name:'Abrir meus pacientes',exact:true}).click();
 await expect(readPage.getByRole('link',{name:'Cadastrar paciente',exact:true})).toHaveCount(0);await expect(readPage.getByText(ownName,{exact:true})).toHaveCount(0);
 await readPage.getByRole('link',{name:sharedName,exact:true}).click();await expect(readPage.getByRole('heading',{name:'Paciente',exact:true})).toBeVisible();await expect(readPage.getByRole('button',{name:'Salvar alterações'})).toHaveCount(0);
 await readPage.goto('/meus-pacientes/novo');await expect(readPage).toHaveURL(/\/meus-pacientes$/);await readContext.close();
});
