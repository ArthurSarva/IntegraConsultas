import {test,expect,type Page,type BrowserContext} from '@playwright/test';
import {createClient} from '@supabase/supabase-js';
import {randomUUID,randomInt} from 'node:crypto';
import {fixture,localOnly,sql} from './local';
import {totp} from './totp';
const f=fixture();localOnly(f.url);
async function login(page:Page,email:string,mfa=false,clinic=f.clinics.a){
 await page.goto('/entrar');await page.getByLabel('Email',{exact:true}).fill(email);await page.getByLabel('Senha',{exact:true}).fill(f.password);await page.getByRole('button',{name:'Entrar',exact:true}).click();
 if(mfa){await expect(page).toHaveURL(/\/seguranca$/);await page.getByRole('button',{name:'Configurar autenticador'}).click();await page.getByText('Configurar manualmente',{exact:true}).click();await page.getByLabel('Código de verificação').fill(totp(await page.locator('.totp-secret').innerText()));await page.getByRole('button',{name:'Confirmar acesso'}).click();}
 await expect(page).toHaveURL(/\/clinicas$/);await page.getByLabel('Clínica',{exact:true}).selectOption(clinic);await page.getByRole('button',{name:'Acessar clínica'}).click();await expect(page).toHaveURL(/\/inicio$/);
}
async function newIdentity(name:string,isDev=false){
 const admin=createClient(f.url,f.adminKey,{auth:{persistSession:false,autoRefreshToken:false}}),email='removal-'+randomUUID()+'@example.invalid';
 const account=await admin.auth.admin.createUser({email,password:f.password,email_confirm:true});expect(account.error).toBeNull();const id=account.data.user!.id;
 sql(`insert into app.users(id,display_name,is_dev) values('${id}','${name}',${isDev});`);return {id,email};
}
function membership(user:string,clinic:string,roles:string[]){
 const id=randomUUID();sql(`do $members$ begin insert into app.memberships(id,clinic_id,user_id) values('${id}','${clinic}','${user}');${roles.map(role=>`insert into app.membership_roles(clinic_id,membership_id,role,scope) values('${clinic}','${id}','${role}','${role==='doctor'?'own':'clinic'}');`).join('')}end $members$;`);return id;
}
async function browserClient(context:BrowserContext){
 const cookies=(await context.cookies()).filter(c=>/^sb-.+-auth-token(?:\.\d+)?$/.test(c.name)).sort((a,b)=>a.name.localeCompare(b.name));const value=cookies.map(c=>c.value).join('');
 const token=JSON.parse(Buffer.from(value.slice(7),'base64url').toString('utf8')).access_token;
 return createClient(f.url,f.key,{db:{schema:'api'},global:{headers:{Authorization:'Bearer '+token}},auth:{persistSession:false,autoRefreshToken:false}});
}
async function confirm(page:Page,label:string){
 await page.getByRole('button',{name:label,exact:true}).click();const form=page.getByRole('form',{name:label,exact:true});await expect(form).toBeVisible();
 await form.getByLabel('Entendi e confirmo esta ação').check();await form.getByRole('button',{name:label,exact:true}).click();
}

test('patient deletion requires confirmation, rejects stale edits and preserves consultation history by archiving',async({page,browser})=>{
 test.setTimeout(120000);await login(page,f.users.receptionA.email);const client=await browserClient(page.context());
 const name='Excluir fictício '+randomUUID(),request={clinic_id:f.clinics.a,patient_id:null,display_name:name,birth_date:'1990-01-01',phone:'+55119'+randomInt(10000000,100000000),email:null,cpf:null,expected_version:null,allow_duplicate:false,own_only:false,operation_id:randomUUID()};
 const saved=await client.rpc('save_patient',request);expect(saved.error).toBeNull();expect(saved.data.status).toBe('saved');const id=saved.data.id;
 await page.goto('/pacientes/'+id);await page.getByRole('button',{name:'Excluir cadastro',exact:true}).click();
 await page.getByRole('form',{name:'Excluir cadastro'}).getByRole('button',{name:'Excluir cadastro',exact:true}).click();expect((await client.rpc('get_patient',{clinic_id:f.clinics.a,patient_id:id,own_only:false})).data).not.toBeNull();
 expect((await client.rpc('save_patient',{...request,patient_id:id,display_name:name+' atualizado',expected_version:1,operation_id:randomUUID()})).data.status).toBe('saved');
 await page.getByRole('form',{name:'Excluir cadastro'}).getByLabel('Entendi e confirmo esta ação').check();await page.getByRole('form',{name:'Excluir cadastro'}).getByRole('button',{name:'Excluir cadastro',exact:true}).click();
 await expect(page.getByRole('alert').filter({hasText:'Este cadastro foi alterado'})).toBeVisible();expect((await client.rpc('get_patient',{clinic_id:f.clinics.a,patient_id:id,own_only:false})).data).not.toBeNull();
 await page.reload();await confirm(page,'Excluir cadastro');await expect(page).toHaveURL(/\/pacientes\?removido=deleted$/);await expect(page.getByRole('status')).toContainText('Cadastro excluído');
 expect((await client.rpc('get_patient',{clinic_id:f.clinics.a,patient_id:id,own_only:false})).data).toBeNull();await page.goto('/pacientes/'+id);await expect(page.getByRole('heading',{name:'404',exact:true})).toBeVisible();
 const archive=await client.rpc('save_patient',{...request,display_name:'Arquivar fictício '+randomUUID(),phone:'+5511999990702',operation_id:randomUUID()});expect(archive.error).toBeNull();
 sql(`select private.retain_patient_for_consultation('${f.clinics.a}','${archive.data.id}');`);
 await page.goto('/pacientes/'+archive.data.id);await confirm(page,'Excluir cadastro');await expect(page).toHaveURL(/\/pacientes\?removido=archived$/);await expect(page.getByRole('status')).toContainText('Cadastro arquivado');
 expect((await client.rpc('get_patient',{clinic_id:f.clinics.a,patient_id:archive.data.id,own_only:false})).data).toBeNull();
 const doctorContext=await browser.newContext(),doctor=await doctorContext.newPage();await login(doctor,f.users.doctor.email);await doctor.goto('/meus-pacientes');await expect(doctor.getByRole('button',{name:'Excluir cadastro'})).toHaveCount(0);await doctorContext.close();
});

test('administrator removes only clinic team, preserving other clinics and blocking an already open session',async({page,browser})=>{
 test.setTimeout(120000);const manager=await newIdentity('Gestor remoção fictício'),member=await newIdentity('Recepção remoção fictícia');membership(manager.id,f.clinics.a,['administrator','doctor']);membership(member.id,f.clinics.a,['reception']);membership(member.id,f.clinics.b,['reception']);
 const otherContext=await browser.newContext(),other=await otherContext.newPage();await login(other,member.email);const oldClient=await browserClient(otherContext);
 await login(page,manager.email,true);await page.goto('/equipe');const own=page.locator('.admin-list>li').filter({hasText:manager.email});await expect(own.getByRole('button',{name:'Remover da clínica'})).toHaveCount(0);
 const row=page.locator('.admin-list>li').filter({hasText:member.email});await row.getByRole('button',{name:'Remover da clínica',exact:true}).click();await row.getByRole('button',{name:'Voltar',exact:true}).click();expect((await oldClient.rpc('current_clinic')).data).toBe(f.clinics.a);
 await row.getByRole('button',{name:'Remover da clínica',exact:true}).click();await row.getByLabel('Entendi e confirmo esta ação').check();await row.getByRole('button',{name:'Remover da clínica',exact:true}).click();await expect(row.getByText('Acesso inativo',{exact:true})).toBeVisible();await expect(row.getByRole('button',{name:'Remover da clínica'})).toHaveCount(0);
 expect((await oldClient.rpc('current_clinic')).data).toBeNull();expect((await oldClient.rpc('select_clinic',{clinic_id:f.clinics.a})).error?.code).toBe('42501');expect((await oldClient.rpc('select_clinic',{clinic_id:f.clinics.b})).error).toBeNull();
 await other.goto('/clinicas');await expect(other.getByLabel('Clínica').locator('option[value="'+f.clinics.a+'"]')).toHaveCount(0);await other.getByLabel('Clínica').selectOption(f.clinics.b);await other.getByRole('button',{name:'Acessar clínica'}).click();await expect(other).toHaveURL(/\/inicio$/);await otherContext.close();
});

test('Dev removes administrator membership and its combined roles only in the selected clinic',async({page,browser})=>{
 test.setTimeout(120000);const dev=await newIdentity('Dev remoção fictício',true),administrator=await newIdentity('Administrador remoção fictício');membership(administrator.id,f.clinics.a,['administrator','doctor','reception']);membership(administrator.id,f.clinics.b,['administrator']);
 const otherContext=await browser.newContext(),other=await otherContext.newPage();await login(other,administrator.email,true);const oldClient=await browserClient(otherContext);
 await login(page,dev.email,true);await page.goto('/dev/administradores');const row=page.locator('.admin-list>li').filter({hasText:administrator.email});await row.getByRole('button',{name:'Remover da clínica',exact:true}).click();await row.getByLabel('Entendi e confirmo esta ação').check();await row.getByRole('button',{name:'Remover da clínica',exact:true}).click();await expect(row.getByText('Acesso inativo',{exact:true})).toBeVisible();
 expect((await oldClient.rpc('current_clinic')).data).toBeNull();expect((await oldClient.rpc('patient_permissions',{clinic_id:f.clinics.a})).error?.code).toBe('42501');expect((await oldClient.rpc('select_clinic',{clinic_id:f.clinics.b})).error).toBeNull();expect((await oldClient.rpc('team_clinic_context',{clinic_id:f.clinics.b})).error).toBeNull();await otherContext.close();
});
