import {test,expect,type Page,type BrowserContext} from '@playwright/test';
import {createClient} from '@supabase/supabase-js';import {randomUUID} from 'node:crypto';
import {fixture,localOnly,sql} from './local';import {totp} from './totp';
const f=fixture();localOnly(f.url);
async function login(page:Page,email:string){
 await page.goto('/entrar');await page.getByLabel('Email',{exact:true}).fill(email);await page.getByLabel('Senha',{exact:true}).fill(f.password);await page.getByRole('button',{name:'Entrar',exact:true}).click();
}
async function setupMfa(page:Page){
 await expect(page).toHaveURL(/\/seguranca$/);await page.getByRole('button',{name:'Configurar autenticador'}).click();
 await page.getByText('Configurar manualmente',{exact:true}).click();
 await page.getByLabel('Código de verificação').fill(totp(await page.locator('.totp-secret').innerText()));
 await page.getByRole('button',{name:'Confirmar acesso'}).click();await expect(page).toHaveURL(/\/clinicas$/);
}
async function jwt(context:BrowserContext){
 const cookies=(await context.cookies()).filter(c=>/^sb-.+-auth-token(?:\.\d+)?$/.test(c.name)).sort((a,b)=>a.name.localeCompare(b.name));
 const value=cookies.map(c=>c.value).join('');if(!value.startsWith('base64-'))throw new Error('Unexpected local fixture cookies');
 return JSON.parse(Buffer.from(value.slice(7),'base64url').toString('utf8')).access_token as string;
}
test('clinic administrator invites reception and doctor with own reception, preserves confirmed accounts and clinic isolation',async({page,browser})=>{
 test.setTimeout(120000);
 const admin=createClient(f.url,f.adminKey,{auth:{persistSession:false,autoRefreshToken:false}});
 const managerEmail='team-manager-'+randomUUID()+'@example.invalid';
 const manager=await admin.auth.admin.createUser({email:managerEmail,password:f.password,email_confirm:true});expect(manager.error).toBeNull();
 const managerId=manager.data.user!.id,membership=randomUUID();
 sql(`do $team_fixture$ begin
 insert into app.users(id,display_name) values('${managerId}','Administrador da equipe');
 insert into app.memberships(id,clinic_id,user_id) values('${membership}','${f.clinics.a}','${managerId}');
 insert into app.membership_roles(clinic_id,membership_id,role,scope) values('${f.clinics.a}','${membership}','administrator','clinic');
 end $team_fixture$;`);
 await login(page,managerEmail);await setupMfa(page);await page.getByLabel('Clínica',{exact:true}).selectOption(f.clinics.a);await page.getByRole('button',{name:'Acessar clínica'}).click();
 await page.getByRole('link',{name:'Gerenciar equipe',exact:true}).click();await expect(page.getByRole('heading',{name:'Equipe da clínica',exact:true})).toBeVisible();
 const access=await jwt(page.context());
 const client=createClient(f.url,f.key,{db:{schema:'api'},global:{headers:{Authorization:'Bearer '+access}},auth:{persistSession:false,autoRefreshToken:false}});
 const rejected='wrong-clinic-'+randomUUID()+'@example.invalid';
 const request={clinic_id:f.clinics.b,operation_id:randomUUID(),email:rejected,display_name:'Não autorizado',team_role:'reception',with_reception:false,duration_minutes:null};
 const wrong=await fetch(f.url+'/functions/v1/provision-team',{method:'POST',headers:{apikey:f.key,Authorization:'Bearer '+access,'Content-Type':'application/json'},body:JSON.stringify(request)});
 expect(wrong.status).toBe(403);
 expect((await admin.auth.admin.listUsers({page:1,perPage:1000})).data.users.some(u=>u.email===rejected)).toBe(false);
 const receptionEmail='new-reception-'+randomUUID()+'@example.invalid';
 await page.getByLabel('Nome da pessoa').fill('Recepção convidada');await page.getByLabel('Email da pessoa').fill(receptionEmail);await page.getByLabel('Função',{exact:true}).selectOption('reception');
 await expect(page.getByLabel('Duração padrão da consulta')).toHaveCount(0);await expect(page.getByLabel('Também exerce a função de recepção')).toHaveCount(0);
 await page.getByRole('button',{name:'Cadastrar pessoa'}).click();await expect(page.getByRole('status')).toContainText('Pessoa vinculada');
 const receptionInvite=await page.getByLabel('Link do convite').inputValue();
 const receiving=await browser.newContext(),recipient=await receiving.newPage();
 await recipient.goto(receptionInvite);await recipient.getByRole('button',{name:'Aceitar convite'}).click();await expect(recipient).toHaveURL(/\/definir-senha$/);
 await recipient.getByLabel('Nova senha',{exact:true}).fill(f.password);await recipient.getByLabel('Confirmar senha',{exact:true}).fill(f.password);await recipient.getByRole('button',{name:'Salvar senha'}).click();
 await login(recipient,receptionEmail);await expect(recipient).toHaveURL(/\/clinicas$/);await expect(recipient.getByRole('option',{name:'Clínica de teste B',exact:true})).toHaveCount(0);
 await recipient.getByLabel('Clínica',{exact:true}).selectOption(f.clinics.a);await recipient.getByRole('button',{name:'Acessar clínica'}).click();await expect(recipient.getByText('Recepção',{exact:true})).toBeVisible();
 await recipient.goto('/equipe');await expect(recipient).toHaveURL(/\/inicio$/);await receiving.close();
 const doctorEmail='new-doctor-'+randomUUID()+'@example.invalid';
 await page.getByLabel('Nome da pessoa').fill('Médico convidado');await page.getByLabel('Email da pessoa').fill(doctorEmail);await page.getByLabel('Função',{exact:true}).selectOption('doctor');
 await expect(page.getByLabel('Duração padrão da consulta').locator('option')).toHaveText(['15 minutos','30 minutos','45 minutos','60 minutos']);
 await page.getByLabel('Duração padrão da consulta').selectOption('45');await page.getByLabel('Também exerce a função de recepção').check();
 await page.getByRole('button',{name:'Cadastrar pessoa'}).click();await expect(page.getByLabel('Link do convite')).not.toHaveValue(receptionInvite);
 const doctorInvite=await page.getByLabel('Link do convite').inputValue();
 const doctorRow=page.locator('li').filter({hasText:doctorEmail});await expect(doctorRow.getByText('Médico e recepção · própria agenda',{exact:true})).toBeVisible();await expect(doctorRow.getByText('Duração padrão: 45 minutos',{exact:true})).toBeVisible();
 const candidate=await client.rpc('team_candidate',{clinic_id:f.clinics.a,email:doctorEmail});expect(candidate.error).toBeNull();
 const operation=randomUUID();const linked={clinic_id:f.clinics.a,user_id:candidate.data.id,email:doctorEmail,display_name:'Médico convidado',team_role:'doctor',with_reception:true,duration_minutes:45,operation_id:operation};
 expect((await client.rpc('link_team_member',linked)).error).toBeNull();expect((await client.rpc('link_team_member',linked)).error).toBeNull();
 expect((await client.rpc('link_team_member',{...linked,team_role:'administrator'})).error?.code).toBe('22023');
 const docContext=await browser.newContext(),doc=await docContext.newPage();await doc.goto(doctorInvite);await doc.getByRole('button',{name:'Aceitar convite'}).click();await expect(doc).toHaveURL(/\/definir-senha$/);
 await doc.getByLabel('Nova senha',{exact:true}).fill(f.password);await doc.getByLabel('Confirmar senha',{exact:true}).fill(f.password);await doc.getByRole('button',{name:'Salvar senha'}).click();await login(doc,doctorEmail);
 await doc.getByLabel('Clínica',{exact:true}).selectOption(f.clinics.a);await doc.getByRole('button',{name:'Acessar clínica'}).click();await expect(doc.getByText('Médico e recepção',{exact:true})).toBeVisible();await expect(doc.getByText(/limitada à sua própria agenda/)).toBeVisible();
 const doctorClient=createClient(f.url,f.key,{db:{schema:'api'},global:{headers:{Authorization:'Bearer '+await jwt(docContext)}},auth:{persistSession:false,autoRefreshToken:false}});
 const workspace=(await doctorClient.rpc('workspace')).data;
 expect(workspace.roles).toEqual(expect.arrayContaining([{role:'doctor',scope:'own'},{role:'reception',scope:'own'}]));
 expect((await doctorClient.rpc('list_team')).error?.code).toBe('42501');await docContext.close();
 // A confirmed account is linked without a new invite or password replacement.
 await page.getByLabel('Nome da pessoa').fill('Recepção existente');await page.getByLabel('Email da pessoa').fill(f.users.existing.email);await page.getByLabel('Função',{exact:true}).selectOption('reception');
 await page.getByRole('button',{name:'Cadastrar pessoa'}).click();await expect(page.getByRole('status')).toContainText('Conta existente vinculada');await expect(page.getByLabel('Link do convite')).toHaveCount(0);
 expect((await createClient(f.url,f.key).auth.signInWithPassword({email:f.users.existing.email,password:f.password})).error).toBeNull();
});
test('team function refuses anonymous and doctor with reception before provisioning',async()=>{
 const email='denied-team-'+randomUUID()+'@example.invalid';const body={clinic_id:f.clinics.a,operation_id:randomUUID(),email,display_name:'Negado',team_role:'doctor',with_reception:false,duration_minutes:30};
 const endpoint=f.url+'/functions/v1/provision-team';
 expect((await fetch(endpoint,{method:'POST',headers:{apikey:f.key,'Content-Type':'application/json'},body:JSON.stringify(body)})).status).toBe(401);
 const client=createClient(f.url,f.key,{auth:{persistSession:false,autoRefreshToken:false}});const result=await client.auth.signInWithPassword({email:f.users.doctor.email,password:f.password});expect(result.error).toBeNull();
 expect((await fetch(endpoint,{method:'POST',headers:{apikey:f.key,Authorization:'Bearer '+result.data.session!.access_token,'Content-Type':'application/json'},body:JSON.stringify(body)})).status).toBe(403);
 const admin=createClient(f.url,f.adminKey,{auth:{persistSession:false,autoRefreshToken:false}});expect((await admin.auth.admin.listUsers({page:1,perPage:1000})).data.users.some(u=>u.email===email)).toBe(false);
});
