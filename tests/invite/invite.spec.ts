import {test,expect} from '@playwright/test';

test('development effect replay keeps the invitation after clearing its URL fragment',async({page})=>{
 await page.goto('/convite#token=synthetic-invitation-not-valid-for-auth');
 await expect(page).toHaveURL(/\/convite$/);
 await expect(page.getByRole('button',{name:'Aceitar convite',exact:true})).toBeVisible();
 await expect(page.getByRole('alert').filter({hasText:'Não encontramos um convite válido'})).toHaveCount(0);
 // A reload must not restore the token from persistent browser storage.
 await page.reload();
 await expect(page.getByRole('alert').filter({hasText:'Não encontramos um convite válido'})).toBeVisible();
 await expect(page.getByRole('button',{name:'Aceitar convite',exact:true})).toHaveCount(0);
});

test('a page opened without an invitation cannot offer acceptance',async({page})=>{
 await page.goto('/convite');
 await expect(page.getByRole('alert').filter({hasText:'Não encontramos um convite válido'})).toBeVisible();
 await expect(page.getByRole('button',{name:'Aceitar convite',exact:true})).toHaveCount(0);
});
