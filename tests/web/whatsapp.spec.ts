import {test,expect,type Page} from '@playwright/test';
import {fixture,localOnly} from './local';
const f=fixture();localOnly(f.url);
async function login(page:Page){
 await page.goto('/entrar');await page.getByLabel('Email',{exact:true}).fill(f.users.receptionA.email);await page.getByLabel('Senha',{exact:true}).fill(f.password);await page.getByRole('button',{name:'Entrar',exact:true}).click();await expect(page).toHaveURL(/\/clinicas$/);
 await page.getByLabel('Clínica',{exact:true}).selectOption(f.clinics.a);await page.getByRole('button',{name:'Acessar clínica'}).click();await expect(page).toHaveURL(/\/inicio$/);
}
test('reception cannot configure clinic sender and webhook remains inactive',async({page,request})=>{
 await login(page);await expect(page.getByRole('link',{name:'Preparar WhatsApp'})).toHaveCount(0);
 await page.goto('/integracoes/whatsapp');await expect(page).toHaveURL(/\/inicio$/);
 expect((await request.get('/api/whatsapp/webhook')).status()).toBe(503);
 expect((await request.post('/api/whatsapp/webhook',{data:{object:'whatsapp_business_account'}})).status()).toBe(503);
});
test('phone enables preference automatically; disabling survives reload and phone edits',async({page})=>{
 await login(page);await page.goto('/pacientes/novo');await page.getByLabel('Nome completo').fill('WhatsApp estrutura fictício');await page.getByLabel('Data de nascimento').fill('2000-01-01');await page.getByLabel('Telefone / WhatsApp').fill('+12025550192');await page.getByRole('button',{name:'Cadastrar paciente',exact:true}).click();await expect(page).toHaveURL(/\/pacientes\/[0-9a-f-]{36}\?salvo=1$/);
 const toggle=page.getByLabel('Habilitar lembretes neste cadastro');await expect(toggle).toBeChecked();await toggle.uncheck();await Promise.all([page.waitForResponse(r=>r.request().method()==='POST' && r.url().includes('/pacientes/')),page.getByRole('button',{name:'Salvar preferência'}).click()]);await expect(toggle).not.toBeChecked();await page.reload();await expect(toggle).not.toBeChecked();
 await page.getByLabel('Telefone / WhatsApp').fill('+12025550193');await page.getByRole('button',{name:'Salvar alterações',exact:true}).click();await expect(page.getByRole('status').filter({hasText:'Cadastro salvo'})).toBeVisible();await expect(toggle).not.toBeChecked();
 await page.setViewportSize({width:390,height:844});expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBe(true);
});


