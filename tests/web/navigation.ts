import {expect,type Page} from '@playwright/test';

// Scope navigation assertions to the sidebar: the dashboard also has shortcuts.
export function moduleLink(page:Page,name:string){
 return page.getByRole('complementary',{name:'Navegação principal',exact:true}).getByRole('link',{name,exact:true});
}
export async function expectReceptionModules(page:Page){
 await expect(moduleLink(page,'Agenda')).toHaveAttribute('href','/agenda');
 await expect(moduleLink(page,'Pacientes')).toHaveAttribute('href','/pacientes');
 for(const name of ['Minha agenda','Meus pacientes','Equipe','Google Agenda'])await expect(moduleLink(page,name)).toHaveCount(0);
}
export async function expectOwnModules(page:Page){
 await expect(moduleLink(page,'Minha agenda')).toHaveAttribute('href','/minha-agenda');
 await expect(moduleLink(page,'Meus pacientes')).toHaveAttribute('href','/meus-pacientes');
 await expect(moduleLink(page,'Automações')).toHaveAttribute('href','/minhas-automacoes');
 for(const name of ['Agenda','Pacientes','Equipe'])await expect(moduleLink(page,name)).toHaveCount(0);
}
