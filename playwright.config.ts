import {defineConfig} from '@playwright/test';
import {readFileSync} from 'node:fs';
const env:Record<string,string>={};
for(const line of readFileSync('.env.test.local','utf8').split('\n')){const i=line.indexOf('=');if(i>0)env[line.slice(0,i)]=line.slice(i+1);}
if(env.NEXT_PUBLIC_SUPABASE_URL!=='http://127.0.0.1:54321')throw new Error('Tests require disposable local Supabase');
export default defineConfig({
 testDir:'./tests/web',testMatch:'**/*.spec.ts',workers:1,fullyParallel:false,timeout:60000,
 reporter:[['list']],use:{baseURL:'http://127.0.0.1:3000',trace:'off'},
 webServer:{command:'pnpm build && pnpm start',url:'http://127.0.0.1:3000/entrar',env,timeout:180000,reuseExistingServer:false}
});

