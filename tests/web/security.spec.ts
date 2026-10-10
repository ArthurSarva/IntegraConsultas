import {test,expect} from '@playwright/test';
import {createClient} from '@supabase/supabase-js';
import {randomUUID} from 'node:crypto';
import {fixture,localOnly} from './local';
import {totp} from './totp';
const f=fixture();localOnly(f.url);
test('HTML has unpredictable nonces, blocks injected scripts and protects forms',async({page,request})=>{
 const first=await request.get('/entrar',{headers:{'x-nonce':'attacker-controlled','Content-Security-Policy':'default-src *'}});
 const second=await request.get('/entrar');
 const p=first.headers()['content-security-policy'],q=second.headers()['content-security-policy'];
 const nonce=p.match(/'nonce-([A-Za-z0-9_-]+)'/)?.[1];expect(nonce).toBeTruthy();expect(p).not.toEqual(q);expect(p).not.toContain('attacker-controlled');
 expect(p).not.toContain('unsafe-eval');expect(p).toContain("frame-ancestors 'none'");expect(p).toContain("form-action 'self'");expect(first.headers()['strict-transport-security']).toBeUndefined();
 const html=await first.text();expect(html).toContain('nonce="'+nonce+'"');
 const violations:string[]=[];page.on('console',m=>{if(/content security policy/i.test(m.text()))violations.push(m.text());});
 await page.goto('/entrar');await page.getByLabel('Email',{exact:true}).fill('absent@example.invalid');await page.getByLabel('Senha',{exact:true}).fill('invalid-password');await page.getByRole('button',{name:'Entrar',exact:true}).click();await expect(page.locator('.form [role="alert"]')).toContainText('Não foi possível entrar');expect(violations).toEqual([]);
 // Inject parser-visible untrusted markup; strict-dynamic intentionally trusts scripts
 // created by an already trusted runtime, including the automation evaluation context.
 await page.route('**/entrar',async route=>{
  const response=await route.fetch();const body=await response.text();
  await route.fulfill({response,body:body.replace('</body>','<script>window.__injected = true</script></body>')});
 });
 await page.goto('/entrar');await expect(page.getByLabel('Email',{exact:true})).toBeVisible();
 expect(await page.evaluate(()=>Boolean((window as unknown as {__injected?:boolean}).__injected))).toBe(false);
 expect(violations.length).toBeGreaterThan(0);
});
test('ordinary session cannot change password',async({page})=>{
 await page.goto('/entrar');await page.getByLabel('Email',{exact:true}).fill(f.users.receptionA.email);await page.getByLabel('Senha',{exact:true}).fill(f.password);await page.getByRole('button',{name:'Entrar',exact:true}).click();await expect(page).toHaveURL(/\/clinicas$/);
 await page.goto('/definir-senha');await expect(page.getByRole('link',{name:'Solicitar recuperação de senha'})).toBeVisible();await expect(page.getByRole('button',{name:'Salvar senha'})).toHaveCount(0);
});
test('revoked session cannot use an already open password form',async({page})=>{
 const admin=createClient(f.url,f.adminKey,{auth:{persistSession:false,autoRefreshToken:false}});
 const email='revoked-'+randomUUID()+'@example.invalid';const created=await admin.auth.admin.createUser({email,password:f.password,email_confirm:true});expect(created.error).toBeNull();const id=created.data.user!.id;
 try{
  const link=await admin.auth.admin.generateLink({type:'recovery',email});expect(link.error).toBeNull();
  await page.goto('/auth/confirmar?type=recovery&token_hash='+link.data.properties!.hashed_token);await expect(page.getByRole('button',{name:'Salvar senha',exact:true})).toBeVisible();
  const cookies=(await page.context().cookies()).filter(c=>/^sb-.+-auth-token(?:\.\d+)?$/.test(c.name)).sort((a,b)=>a.name.localeCompare(b.name));
  const serialized=cookies.map(c=>c.value).join('');expect(serialized.startsWith('base64-')).toBe(true);
  const session=JSON.parse(Buffer.from(serialized.slice(7),'base64url').toString('utf8'));
  expect((await admin.auth.admin.signOut(session.access_token,'global')).error).toBeNull();
  await page.getByLabel('Nova senha',{exact:true}).fill(f.password+'Changed');await page.getByLabel('Confirmar senha',{exact:true}).fill(f.password+'Changed');await page.getByRole('button',{name:'Salvar senha',exact:true}).click();
  await expect(async()=>{if(new URL(page.url()).pathname==='/entrar')return;await expect(page.locator('.form [role="alert"]')).toContainText('Sua sessão expirou');}).toPass({timeout:10000});
  const c=createClient(f.url,f.key,{auth:{persistSession:false,autoRefreshToken:false}});
  expect((await c.auth.signInWithPassword({email,password:f.password+'Changed'})).error).not.toBeNull();
  expect((await c.auth.signInWithPassword({email,password:f.password})).error).toBeNull();
 }finally{await admin.auth.admin.deleteUser(id);}
});
test('recovery does not bypass an enrolled authenticator and valid challenge changes password',async({page})=>{
 test.setTimeout(90000);
 const admin=createClient(f.url,f.adminKey,{auth:{persistSession:false,autoRefreshToken:false}});
 const email='security-'+randomUUID()+'@example.invalid';const created=await admin.auth.admin.createUser({email,password:f.password,email_confirm:true});expect(created.error).toBeNull();const id=created.data.user!.id;
 const c=createClient(f.url,f.key,{auth:{persistSession:false,autoRefreshToken:false}});
 expect((await c.auth.signInWithPassword({email,password:f.password})).error).toBeNull();
 const enrollment=await c.auth.mfa.enroll({factorType:'totp',friendlyName:'Security test'});expect(enrollment.error).toBeNull();const factor=enrollment.data!;
 expect((await c.auth.mfa.challengeAndVerify({factorId:factor.id,code:totp(factor.totp.secret)})).error).toBeNull();
 // No existing fixture credentials are changed. This account belongs only to this test.
 const link=await admin.auth.admin.generateLink({type:'recovery',email});expect(link.error).toBeNull();
 await page.goto('/auth/confirmar?type=recovery&token_hash='+link.data.properties!.hashed_token);await expect(page).toHaveURL(/\/definir-senha$/);await expect(page.getByLabel('Código do autenticador')).toBeVisible();
 await page.getByLabel('Nova senha',{exact:true}).fill(f.password+'New');await page.getByLabel('Confirmar senha',{exact:true}).fill(f.password+'New');
 await page.getByLabel('Código do autenticador').fill(totp(factor.totp.secret)==='000000'?'000001':'000000');await page.getByRole('button',{name:'Salvar senha',exact:true}).click();await expect(page.locator('.form [role="alert"]')).toContainText('Código inválido');
 // Wait for a new code instead of replaying the code used during enrollment.
 await new Promise(resolve=>setTimeout(resolve,30000-(Date.now()%30000)+1000));
 // React resets uncontrolled form fields after the completed action, including errors.
 await page.getByLabel('Nova senha',{exact:true}).fill(f.password+'New');
 await page.getByLabel('Confirmar senha',{exact:true}).fill(f.password+'New');
 await page.getByLabel('Código do autenticador').fill(totp(factor.totp.secret));
 await Promise.all([page.waitForResponse(r=>r.request().method()==='POST'&&r.url().includes('/definir-senha'),{timeout:10000}),page.getByRole('button',{name:'Salvar senha',exact:true}).click()]);
 await expect(page.locator('.form [role="alert"]')).toHaveCount(0);await expect(page).toHaveURL(/\/entrar\?senha=atualizada$/);
 expect((await c.auth.signInWithPassword({email,password:f.password+'New'})).error).toBeNull();
 expect((await c.auth.signInWithPassword({email,password:f.password})).error).not.toBeNull();
 await admin.auth.admin.deleteUser(id);
});

