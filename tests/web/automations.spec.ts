import {test,expect,type Page} from '@playwright/test';
import {createClient} from '@supabase/supabase-js';
import {randomUUID} from 'node:crypto';
import {fixture,localOnly,sql} from './local';
const f=fixture();localOnly(f.url);
const day=new Intl.DateTimeFormat('sv-SE',{timeZone:'America/Sao_Paulo'}).format(new Date(Date.now()+10*86400000));
const worker=()=>createClient(f.url,f.adminKey,{db:{schema:'api'},auth:{persistSession:false,autoRefreshToken:false}});
async function api(role:string,clinic=f.clinics.a){const c=createClient(f.url,f.key,{db:{schema:'api'},auth:{persistSession:false,autoRefreshToken:false}});expect((await c.auth.signInWithPassword({email:f.users[role].email,password:f.password})).error).toBeNull();expect((await c.rpc('select_clinic',{clinic_id:clinic})).error).toBeNull();return c;}
async function setup(){
 const admin=worker(),email='automation-'+randomUUID()+'@example.invalid',account=await admin.auth.admin.createUser({email,password:f.password,email_confirm:true});expect(account.error).toBeNull();const user=account.data.user!.id,member=randomUUID();
 sql(`do $fixture$ begin insert into app.users(id,display_name) values('${user}','Médico automação fictício');insert into app.memberships(id,clinic_id,user_id) values('${member}','${f.clinics.a}','${user}');insert into app.membership_roles values('${f.clinics.a}','${member}','doctor','own');insert into app.doctor_settings values('${f.clinics.a}','${member}',30);insert into app.availability_windows(clinic_id,membership_id,weekday,starts_at,ends_at) select '${f.clinics.a}','${member}',i,'08:00','18:00' from generate_series(0,6)i;end $fixture$;`);
 const client=await api('receptionA'),person=await client.rpc('save_patient',{clinic_id:f.clinics.a,patient_id:null,display_name:'Paciente automação '+randomUUID(),birth_date:'1990-01-01',phone:'+5511999990701',email:null,cpf:null,expected_version:null,allow_duplicate:true,own_only:false,operation_id:randomUUID()});expect(person.error).toBeNull();
 const appointment=await client.rpc('save_appointment',{clinic_id:f.clinics.a,doctor_id:member,patient_id:person.data.id,appointment_id:null,start_local:day+'T09:00',duration_minutes:30,expected_version:null,replace_id:null,replace_version:null,own_only:false,operation_id:randomUUID()});expect(appointment.error).toBeNull();expect(appointment.data.status).toBe('saved');return {client,email,id:appointment.data.id as string};
}
async function login(page:Page,email:string){await page.goto('/entrar');await page.getByLabel('Email',{exact:true}).fill(email);await page.getByLabel('Senha',{exact:true}).fill(f.password);await page.getByRole('button',{name:'Entrar',exact:true}).click();await expect(page).toHaveURL(/\/clinicas$/);await page.getByLabel('Clínica',{exact:true}).selectOption(f.clinics.a);await page.getByRole('button',{name:'Acessar clínica'}).click();await expect(page).toHaveURL(/\/inicio$/);}
async function tasks(client:Awaited<ReturnType<typeof api>>,id:string,own=false){const r=await client.rpc('list_automations',{clinic_id:f.clinics.a,own_only:own,page_number:0,appointment_id:id});expect(r.error).toBeNull();return r.data.records as {id:string;appointment_version:number;kind:string;status:string;reason:string|null}[];}

test('reception sees versioned tasks and integration pendencies without claiming a sent message',async({page})=>{
 const s=await setup();expect(await tasks(s.client,s.id)).toHaveLength(2);
 await login(page,f.users.receptionA.email);await page.getByRole('link',{name:'Acompanhar automações'}).click();await expect(page.getByRole('heading',{name:'Automações da clínica'})).toBeVisible();
 await page.goto('/automacoes?consulta='+s.id);await expect(page.locator('.automation-list>li')).toHaveCount(2);await expect(page.getByText('WhatsApp ainda não envia mensagens.',{exact:false})).toBeVisible();
 await page.goto('/agenda/'+s.id);await page.getByRole('button',{name:'Registrar confirmação'}).click();await expect(page.locator('.appointment-status')).toHaveText('Confirmada');
 const confirmed=await tasks(s.client,s.id);expect(confirmed.filter(t=>t.appointment_version===1).every(t=>t.status==='cancelled')).toBe(true);expect(confirmed.filter(t=>t.appointment_version===2)).toHaveLength(2);
 expect((await s.client.rpc('change_appointment_status',{clinic_id:f.clinics.a,appointment_id:s.id,next_status:'cancelada',expected_version:2,own_only:false,operation_id:randomUUID()})).error).toBeNull();
 const claim=await worker().rpc('claim_automation',{clinic_id:f.clinics.a,batch_size:50});expect(claim.error).toBeNull();const task=claim.data.find((t:{appointment:string})=>t.appointment===s.id);expect(task.intent).toBe('remove');expect((await worker().rpc('finish_automation',{clinic_id:f.clinics.a,task_id:task.id,lease_token:task.lease,outcome:'integration_not_configured'})).error).toBeNull();
 await page.goto('/automacoes?consulta='+s.id);await expect(page.getByText('Integração ainda não configurada',{exact:true})).toBeVisible();expect((await tasks(s.client,s.id)).every(t=>t.status!=='completed')).toBe(true);
 await page.setViewportSize({width:390,height:844});expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBe(true);
});

test('concurrent technical workers reserve each due task once and user sessions cannot finish it',async()=>{
 const s=await setup(),first=worker(),second=worker();const claims=await Promise.all([first.rpc('claim_automation',{clinic_id:f.clinics.a,batch_size:50}),second.rpc('claim_automation',{clinic_id:f.clinics.a,batch_size:50})]);expect(claims.every(r=>!r.error)).toBe(true);
 const all=claims.flatMap(r=>r.data);expect(new Set(all.map(t=>t.id)).size).toBe(all.length);const selected=all.filter(t=>t.appointment===s.id);expect(selected).toHaveLength(1);
 expect((await s.client.rpc('finish_automation',{clinic_id:f.clinics.a,task_id:selected[0].id,lease_token:selected[0].lease,outcome:'integration_not_configured'})).error).not.toBeNull();
 const args={clinic_id:f.clinics.a,task_id:selected[0].id,lease_token:selected[0].lease,outcome:'transient_failure'};expect((await first.rpc('finish_automation',args)).data.status).toBe('saved');expect((await first.rpc('finish_automation',args)).data.status).toBe('already_finished');
 const current=await tasks(s.client,s.id);expect(current.find(t=>t.id===selected[0].id)?.status).toBe('retry');expect(current.some(t=>t.kind==='whatsapp_reminder'&&t.status==='pending')).toBe(true);
});

test('doctor reads only own automation tasks and another clinic cannot discover appointment tasks',async({page})=>{
 const own=await setup(),other=await setup();await login(page,own.email);await page.getByRole('link',{name:'Acompanhar automações'}).click();await expect(page).toHaveURL(/\/minhas-automacoes$/);await expect(page.locator('.automation-list>li')).toHaveCount(2);
 await page.goto('/minhas-automacoes?consulta='+other.id);await expect(page.locator('.automation-list>li')).toHaveCount(0);
 const b=await api('receptionB',f.clinics.b);const foreign=await b.rpc('list_automations',{clinic_id:f.clinics.b,own_only:false,page_number:0,appointment_id:own.id});expect(foreign.error).toBeNull();expect(foreign.data.records).toHaveLength(0);
 expect((await b.rpc('list_automations',{clinic_id:f.clinics.a,own_only:false,page_number:0,appointment_id:own.id})).error?.code).toBe('42501');
});
