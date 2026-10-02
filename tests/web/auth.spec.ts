import {test,expect,type Page} from '@playwright/test';
import {createClient} from '@supabase/supabase-js';
import {totp} from './totp';
import {fixture,localOnly,sql} from './local';
const f=fixture();localOnly(f.url);
async function login(page:Page,role:string){
 await page.goto('/entrar');await page.getByLabel('Email',{exact:true}).fill(f.users[role].email);
 await page.getByLabel('Senha',{exact:true}).fill(f.password);await page.getByRole('button',{name:'Entrar',exact:true}).click();
}
function client(){return createClient(f.url,f.key,{db:{schema:'api'},auth:{persistSession:false,autoRefreshToken:false}});}
test('email login provider is enabled while public signup remains disabled',async()=>{
 const c=client();
 const result=await c.auth.signUp({email:'blocked-signup@example.invalid',password:f.password});
 expect(result.error?.code).toBe('signup_disabled');
 expect(result.data.user).toBeNull();
});
test('protected routes redirect; invalid credentials stay generic',async({page})=>{
 await page.goto('/inicio');await expect(page).toHaveURL(/\/entrar$/);
 await page.getByLabel('Email',{exact:true}).fill('missing@example.invalid');
 await page.getByLabel('Senha',{exact:true}).fill('invalid-password');
 await page.getByRole('button',{name:'Entrar',exact:true}).click();
 await expect(page.getByRole('alert').filter({hasText:'Não foi possível entrar'})).toBeVisible();
});
test('reception can select only its clinic and logout clears access',async({page})=>{
 await login(page,'receptionA');await expect(page).toHaveURL(/\/clinicas$/);
 const cookies=await page.context().cookies();
 expect(cookies.filter(c=>c.name.startsWith('sb-')).length).toBeGreaterThan(0);
 expect(cookies.filter(c=>c.name.startsWith('sb-')).every(c=>c.httpOnly&&c.sameSite==='Lax')).toBe(true);
 await expect(page.getByRole('option',{name:'Clínica de teste B',exact:true})).toHaveCount(0);
 await page.getByLabel('Clínica',{exact:true}).selectOption(f.clinics.a);
 await page.getByRole('button',{name:'Acessar clínica'}).click();await expect(page).toHaveURL(/\/inicio$/);
 await expect(page.getByText('Recepção',{exact:true})).toBeVisible();
 await page.getByRole('button',{name:'Sair',exact:true}).click();await expect(page).toHaveURL(/\/entrar$/);
 await page.goto('/inicio');await expect(page).toHaveURL(/\/entrar$/);
});
test('doctor with reception retains own scope',async({page})=>{
 await login(page,'doctor');await page.getByLabel('Clínica',{exact:true}).selectOption(f.clinics.a);
 await page.getByRole('button',{name:'Acessar clínica'}).click();
 await expect(page.getByText('Médico e recepção',{exact:true})).toBeVisible();
 await expect(page.getByText(/limitada à sua própria agenda/)).toBeVisible();
});
for(const role of ['administrator','dev']){
 test(role+' requires MFA; enrolling and verifying reaches clinic selection',async({page})=>{
  await login(page,role);await expect(page).toHaveURL(/\/seguranca$/);
  await page.goto('/clinicas');await expect(page).toHaveURL(/\/seguranca$/);
  await page.getByRole('button',{name:'Configurar autenticador'}).click();
  await page.getByText('Configurar manualmente',{exact:true}).click();
  const secret=await page.locator('.totp-secret').innerText();
  await page.getByLabel('Código de verificação').fill(totp(secret));
  await page.getByRole('button',{name:'Confirmar acesso'}).click();await expect(page).toHaveURL(/\/clinicas$/);
  await expect(page.getByRole('option',{name:'Clínica de teste B',exact:true})).toHaveCount(role==='dev'?1:0);
 });
}
test('Auth account without provisioned profile has no clinic access',async({page})=>{
 await login(page,'unprovisioned');await expect(page).toHaveURL(/\/sem-acesso$/);
});
test('real JWTs isolate clinics; metadata cannot elevate; revocation invalidates old JWT',async()=>{
 const a=client(),b=client();
 for(const [c,role] of [[a,'receptionA'],[b,'receptionB']] as const){
  const {error}=await c.auth.signInWithPassword({email:f.users[role].email,password:f.password});expect(error).toBeNull();
 }
 const listA=await a.rpc('list_clinics');expect(listA.data?.map((c:{id:string})=>c.id)).toEqual([f.clinics.a]);
 expect((await a.rpc('session_profile')).data.is_dev).toBe(false);
 expect((await a.rpc('select_clinic',{clinic_id:f.clinics.b})).error?.code).toBe('42501');
 expect((await a.rpc('select_clinic',{clinic_id:f.clinics.a})).error).toBeNull();
 expect((await b.rpc('workspace')).data).toBeNull();
 expect((await b.rpc('select_clinic',{clinic_id:f.clinics.b})).error).toBeNull();
 expect((await a.rpc('workspace')).data.id).toBe(f.clinics.a);
 expect((await b.rpc('workspace')).data.id).toBe(f.clinics.b);
 sql("update app.memberships set active=false where user_id='"+f.users.receptionA.id+"';");
 try{expect((await a.rpc('workspace')).data).toBeNull();expect((await a.rpc('select_clinic',{clinic_id:f.clinics.a})).error?.code).toBe('42501');}
 finally{sql("update app.memberships set active=true where user_id='"+f.users.receptionA.id+"';");}
 const session=(await b.auth.getSession()).data.session!;
 expect((await b.auth.signOut({scope:'local'})).error).toBeNull();
 const res=await fetch(f.url+'/rest/v1/rpc/workspace',{method:'POST',headers:{apikey:f.key,Authorization:'Bearer '+session.access_token,'Content-Profile':'api','Content-Type':'application/json'},body:'{}'});
 expect(await res.json()).toBeNull();
});
test('recovery token defines password and requires a new login',async({page})=>{
 const admin=createClient(f.url,f.adminKey,{auth:{persistSession:false,autoRefreshToken:false}});
 const {data,error}=await admin.auth.admin.generateLink({type:'recovery',email:f.users.unprovisioned.email});
 expect(error).toBeNull();
 await page.goto('/auth/confirmar?type=recovery&token_hash='+data.properties!.hashed_token);
 await expect(page).toHaveURL(/\/definir-senha$/);
 const newPassword=f.password+'New';
 await page.getByLabel('Nova senha',{exact:true}).fill(newPassword);
 await page.getByLabel('Confirmar senha',{exact:true}).fill(newPassword);
 await page.getByRole('button',{name:'Salvar senha',exact:true}).click();
 await expect(page).toHaveURL(/\/entrar\?senha=atualizada$/);
 const c=client();expect((await c.auth.signInWithPassword({email:f.users.unprovisioned.email,password:newPassword})).error).toBeNull();
});
test('recovery form accepts valid email without revealing account existence',async({page})=>{
 await page.goto('/recuperar');
 await page.getByLabel('Email',{exact:true}).fill(f.users.receptionB.email);
 await page.getByRole('button',{name:'Solicitar recuperação'}).click();
 await expect(page.getByRole('status')).toContainText('Se o endereço puder receber');
 await expect(page.locator('.form [role="alert"]')).toHaveCount(0);
});
