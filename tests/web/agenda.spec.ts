import {moduleLink} from './navigation';
import {test,expect,type Page} from '@playwright/test';
import {createClient} from '@supabase/supabase-js';
import {randomUUID} from 'node:crypto';
import {fixture,localOnly,sql} from './local';
const f=fixture();localOnly(f.url);
const day=new Intl.DateTimeFormat('sv-SE',{timeZone:'America/Sao_Paulo'}).format(new Date(Date.now()+7*86400000));
const weekday=new Date(day+'T12:00:00Z').getUTCDay();
async function api(role:string,clinic=f.clinics.a){const client=createClient(f.url,f.key,{db:{schema:'api'},auth:{persistSession:false,autoRefreshToken:false}});expect((await client.auth.signInWithPassword({email:f.users[role].email,password:f.password})).error).toBeNull();expect((await client.rpc('select_clinic',{clinic_id:clinic})).error).toBeNull();return client;}
async function login(page:Page,email:string){await page.goto('/entrar');await page.getByLabel('Email',{exact:true}).fill(email);await page.getByLabel('Senha',{exact:true}).fill(f.password);await page.getByRole('button',{name:'Entrar',exact:true}).click();await expect(page).toHaveURL(/\/clinicas$/);await page.getByLabel('Clínica',{exact:true}).selectOption(f.clinics.a);await page.getByRole('button',{name:'Acessar clínica'}).click();await expect(page).toHaveURL(/\/inicio$/);}
async function doctor(reception=true,both=false,availability=true){
 const admin=createClient(f.url,f.adminKey,{auth:{persistSession:false,autoRefreshToken:false}}),email='agenda-'+randomUUID()+'@example.invalid',name='Médico agenda fictício '+randomUUID();
 const account=await admin.auth.admin.createUser({email,password:f.password,email_confirm:true});expect(account.error).toBeNull();const user=account.data.user!.id,a=randomUUID(),b=both?randomUUID():null;
 const statements=[`insert into app.users(id,display_name) values('${user}','${name}');`];
 for(const [clinic,id] of [[f.clinics.a,a],...(b?[[f.clinics.b,b]]:[])]){
  statements.push(`insert into app.memberships(id,clinic_id,user_id) values('${id}','${clinic}','${user}');insert into app.membership_roles values('${clinic}','${id}','doctor','own');insert into app.doctor_settings values('${clinic}','${id}',30);`);
  if(reception)statements.push(`insert into app.membership_roles values('${clinic}','${id}','reception','own');`);
  if(availability)statements.push(`insert into app.availability_windows(clinic_id,membership_id,weekday,starts_at,ends_at) select '${clinic}','${id}',i,'08:00','18:00' from generate_series(0,6)i;`);
 }
 sql('do $agenda_fixture$ begin '+statements.join('')+' end $agenda_fixture$;');return {user,email,name,a,b};
}
async function patient(client:Awaited<ReturnType<typeof api>>,clinic:string,suffix:string){const name='Paciente agenda fictício '+randomUUID(),response=await client.rpc('save_patient',{clinic_id:clinic,patient_id:null,display_name:name,birth_date:'1990-01-01',phone:'+551199999'+suffix,email:null,cpf:null,expected_version:null,allow_duplicate:true,own_only:false,operation_id:randomUUID()});expect(response.error).toBeNull();expect(response.data.status).toBe('saved');return {id:response.data.id as string,name};}
function request(clinic:string,member:string,person:string,clock='09:00'){return {clinic_id:clinic,doctor_id:member,patient_id:person,appointment_id:null,start_local:day+'T'+clock,duration_minutes:30,expected_version:null,replace_id:null,replace_version:null,own_only:false,operation_id:randomUUID()};}
async function pickPatient(page:Page,person:{id:string;name:string}){await page.getByLabel('Pesquisar paciente por nome ou contato').fill(person.name);await page.getByRole('button',{name:'Pesquisar paciente',exact:true}).click();await expect(page.getByLabel('Paciente',{exact:true}).locator('option[value="'+person.id+'"]')).toHaveCount(1);await page.getByLabel('Paciente',{exact:true}).selectOption(person.id);}
async function confirm(page:Page,label:string){await page.getByRole('button',{name:label,exact:true}).click();const form=page.getByRole('form',{name:label,exact:true});await form.getByLabel('Entendi e confirmo esta ação').check();await form.getByRole('button',{name:label,exact:true}).click();}

test('reception configures hours, schedules, confirms, reschedules, replaces, blocks and cancels with history preserved',async({page})=>{
 test.setTimeout(120000);const d=await doctor(true,false,false),client=await api('receptionA'),p=await patient(client,f.clinics.a,'0901'),p2=await patient(client,f.clinics.a,'0902');
 await login(page,f.users.receptionA.email);await moduleLink(page,'Agenda').click();await expect(page.getByRole('heading',{name:'Agenda da clínica',exact:true})).toBeVisible();
 await page.goto('/agenda/horarios?medico='+d.a);await page.getByLabel('Dia da semana').selectOption(String(weekday));await page.getByLabel('Início do atendimento').fill('08:00');await page.getByLabel('Fim do atendimento').fill('18:00');await page.getByRole('button',{name:'Adicionar horário de atendimento'}).click();await expect(page.getByRole('status')).toContainText('Horário de atendimento salvo');
 await page.goto('/agenda/nova?data='+day+'&medico='+d.a);await pickPatient(page,p);await expect(page.getByLabel('Duração da consulta')).toBeDisabled();await page.getByLabel('Data e horário da consulta').fill(day+'T09:00');await page.getByRole('button',{name:'Agendar consulta',exact:true}).click();await expect(page).toHaveURL(/\/agenda\/[0-9a-f-]{36}\?salvo=1$/);const first=new URL(page.url()).pathname.split('/').at(-1)!;
 await expect(page.locator('.appointment-status')).toHaveText('Agendada');await expect(page.getByRole('button',{name:'Registrar falta'})).toBeDisabled();await page.getByRole('button',{name:'Registrar confirmação'}).click();await expect(page.locator('.appointment-status')).toHaveText('Confirmada');
 await page.getByText('Reagendar consulta',{exact:true}).click();await page.getByLabel('Data e horário da consulta').fill(day+'T10:00');await page.getByRole('button',{name:'Salvar reagendamento'}).click();await expect(page.locator('.appointment-status')).toHaveText('Agendada');await expect(page.locator('.agenda-history>li')).toHaveCount(3);
 await page.goto('/agenda/nova?data='+day+'&medico='+d.a);await pickPatient(page,p2);await page.getByLabel('Data e horário da consulta').fill(day+'T10:00');await page.getByLabel('Substituir consulta existente').check();await page.getByLabel('Consulta a substituir').selectOption(first);await page.getByRole('button',{name:'Agendar consulta',exact:true}).click();await expect(page).toHaveURL(/\/agenda\/[0-9a-f-]{36}\?salvo=1$/);const replacement=new URL(page.url()).pathname.split('/').at(-1)!;
 expect((await client.rpc('get_appointment',{clinic_id:f.clinics.a,appointment_id:first,own_only:false})).data.status).toBe('cancelada');expect((await client.rpc('get_appointment',{clinic_id:f.clinics.a,appointment_id:replacement,own_only:false})).data.replaces_id).toBe(first);
 await page.goto('/pacientes/'+p2.id);await expect(page.getByRole('heading',{name:'Consultas deste paciente'})).toBeVisible();await expect(page.getByRole('link',{name:'Ver consulta',exact:true})).toHaveCount(1);
 await page.goto('/agenda/horarios?medico='+d.a);await page.getByLabel('Início do bloqueio').fill(day+'T11:00');await page.getByLabel('Fim do bloqueio').fill(day+'T12:00');await page.getByRole('button',{name:'Criar bloqueio'}).click();await expect(page.getByRole('status')).toContainText('Horário bloqueado');
 expect((await client.rpc('save_appointment',request(f.clinics.a,d.a,p.id,'11:00'))).data.status).toBe('occupied');
 await page.goto('/agenda?data='+day+'&medico='+d.a);await confirm(page,'Retirar bloqueio');await expect(page.getByRole('heading',{name:'Horários bloqueados'})).toHaveCount(0);
 await page.goto('/agenda/'+replacement);await confirm(page,'Cancelar consulta');await expect(page.locator('.appointment-status')).toHaveText('Cancelada');await expect(page.locator('.agenda-history>li')).toHaveCount(2);
 expect((await client.rpc('save_appointment',request(f.clinics.a,d.a,p.id,'10:00'))).data.status).toBe('saved');
});

test('simultaneous bookings and replacements across clinics preserve one global slot without exposing clinic data',async()=>{
 test.setTimeout(120000);const d=await doctor(true,true),a=await api('receptionA'),b=await api('receptionB',f.clinics.b),pa=await patient(a,f.clinics.a,'0903'),pb=await patient(b,f.clinics.b,'0904');
 const ra=request(f.clinics.a,d.a,pa.id),rb=request(f.clinics.b,d.b!,pb.id);
 const responses=await Promise.all([a.rpc('save_appointment',ra),b.rpc('save_appointment',rb)]);expect(responses.every(r=>!r.error)).toBe(true);expect(responses.map(r=>r.data.status).sort()).toEqual(['occupied','saved']);expect(responses.find(r=>r.data.status==='occupied')!.data).toEqual({status:'occupied'});
 const winner=responses[0].data.status==='saved'?a:b,winRequest=responses[0].data.status==='saved'?ra:rb,loser=winner===a?b:a,loseRequest=winner===a?rb:ra,id=responses.find(r=>r.data.status==='saved')!.data.id;
 expect((await loser.rpc('save_appointment',{...loseRequest,replace_id:id,replace_version:1,operation_id:randomUUID()})).error?.code).toBe('42501');
 const retries=await Promise.all([winner.rpc('save_appointment',winRequest),winner.rpc('save_appointment',winRequest)]);expect(retries.every(r=>!r.error&&r.data.id===id)).toBe(true);
 const edits=await Promise.all(['10:00','11:00'].map(clock=>winner.rpc('save_appointment',{...winRequest,appointment_id:id,expected_version:1,start_local:day+'T'+clock,operation_id:randomUUID()})));expect(edits.every(r=>!r.error)).toBe(true);expect(edits.map(r=>r.data.status).sort()).toEqual(['conflict','saved']);
 expect((await loser.rpc('get_appointment',{clinic_id:loseRequest.clinic_id,appointment_id:id,own_only:false})).data).toBeNull();
 const anon=createClient(f.url,f.key,{db:{schema:'api'},auth:{persistSession:false,autoRefreshToken:false}});expect((await anon.rpc('save_appointment',ra)).error).not.toBeNull();
});

test('doctor-only access stays read-only while own reception can choose duration only for the own agenda',async({page})=>{
 test.setTimeout(120000);const readonly=await doctor(false),own=await doctor(true),reception=await api('receptionA'),person=await patient(reception,f.clinics.a,'0905');
 const saved=await reception.rpc('save_appointment',request(f.clinics.a,readonly.a,person.id));expect(saved.error).toBeNull();
 await login(page,readonly.email);await moduleLink(page,'Minha agenda').click();await expect(page.getByRole('link',{name:'Agendar consulta',exact:true})).toHaveCount(0);await page.goto('/minha-agenda/'+saved.data.id);await expect(page.getByRole('heading',{name:'Atualizar situação'})).toHaveCount(0);
 await page.goto('/minha-agenda/horarios');await expect(page.getByRole('button',{name:'Adicionar horário de atendimento'})).toHaveCount(0);await page.getByLabel('Duração padrão das novas consultas').selectOption('45');await page.getByRole('button',{name:'Salvar duração padrão'}).click();await expect(page.getByRole('status')).toContainText('Duração padrão salva');
 expect((await reception.rpc('get_appointment',{clinic_id:f.clinics.a,appointment_id:saved.data.id,own_only:false})).data.duration).toBe(30);
 const ownClient=createClient(f.url,f.key,{db:{schema:'api'},auth:{persistSession:false,autoRefreshToken:false}});expect((await ownClient.auth.signInWithPassword({email:own.email,password:f.password})).error).toBeNull();expect((await ownClient.rpc('select_clinic',{clinic_id:f.clinics.a})).error).toBeNull();
 const ownPatient=await ownClient.rpc('save_patient',{clinic_id:f.clinics.a,patient_id:null,display_name:'Paciente próprio agenda '+randomUUID(),birth_date:'1990-01-01',phone:'+5511999990906',email:null,cpf:null,expected_version:null,allow_duplicate:true,own_only:true,operation_id:randomUUID()});expect(ownPatient.error).toBeNull();
 expect((await ownClient.rpc('save_appointment',{...request(f.clinics.a,own.a,ownPatient.data.id,'13:00'),duration_minutes:45,own_only:true})).data.status).toBe('saved');
 expect((await ownClient.rpc('save_appointment',request(f.clinics.a,readonly.a,person.id,'14:00'))).error?.code).toBe('42501');expect((await ownClient.rpc('agenda_doctors',{clinic_id:f.clinics.a,own_only:true})).data).toHaveLength(1);
 await page.goto('/agenda');await expect(page).toHaveURL(/\/minha-agenda$/);
});
