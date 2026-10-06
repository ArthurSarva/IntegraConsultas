import {test,expect,type Page} from '@playwright/test';
import {fixture,localOnly} from './local';
const f=fixture();localOnly(f.url);
async function login(page:Page,role:string){
 await page.goto('/entrar');await page.getByLabel('Email',{exact:true}).fill(f.users[role].email);await page.getByLabel('Senha',{exact:true}).fill(f.password);
 await page.getByRole('button',{name:'Entrar',exact:true}).click();await expect(page).toHaveURL(/\/clinicas$/);
 await page.getByLabel('Clínica',{exact:true}).selectOption(f.clinics.a);await page.getByRole('button',{name:'Acessar clínica'}).click();await expect(page).toHaveURL(/\/inicio$/);
}
test('reception cannot connect a doctor Google calendar',async({page})=>{
 await login(page,'receptionA');await expect(page.getByRole('link',{name:'Configurar Google Agenda'})).toHaveCount(0);
 await page.goto('/integracoes/google');await expect(page).toHaveURL(/\/inicio$/);
});
test('doctor sees own connection and rejects an OAuth callback without state cookie',async({page})=>{
 await login(page,'doctor');await page.getByRole('link',{name:'Configurar Google Agenda'}).click();await expect(page.getByRole('heading',{name:'Conectar Google Agenda',exact:true})).toBeVisible();
 await expect(page.getByText('A integração Google ainda precisa ser configurada pela administração do sistema.',{exact:true})).toBeVisible();
 await page.goto('/integracoes/google/retorno?code=synthetic-invalid&state=synthetic-invalid');await expect(page).toHaveURL(/\/integracoes\/google\?erro=expirado$/);
 await expect(page.getByRole('alert')).toBeVisible();await page.setViewportSize({width:390,height:844});expect(await page.evaluate(()=>document.documentElement.scrollWidth<=window.innerWidth)).toBe(true);
});
