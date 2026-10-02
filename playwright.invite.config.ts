import {defineConfig} from '@playwright/test';

// No Auth call or invite acceptance: all tokens in this suite are synthetic.
export default defineConfig({
 testDir:'./tests/invite',workers:1,timeout:30000,reporter:[['list']],
 use:{baseURL:'http://127.0.0.1:3000',trace:'off',channel:process.env.PLAYWRIGHT_CHANNEL},
 webServer:{command:'pnpm dev',url:'http://127.0.0.1:3000/convite',timeout:120000,
  reuseExistingServer:!process.env.CI,
  env:{NEXT_PUBLIC_SUPABASE_URL:'http://127.0.0.1:54321',NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY:'sb_publishable_invite_regression',APP_ORIGIN:'http://127.0.0.1:3000'}
 }
});
