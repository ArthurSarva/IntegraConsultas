import {spawnSync} from 'node:child_process';
import {readFileSync} from 'node:fs';
export type Fixture={url:string;key:string;adminKey:string;password:string;clinics:{a:string;b:string};users:Record<string,{id:string;email:string}>};
export function fixture():Fixture {return JSON.parse(readFileSync('.env.web-fixture.json','utf8'));}
export function localOnly(url:string) {if(new URL(url).origin!=='http://127.0.0.1:54321')throw new Error('Web fixtures require disposable local Supabase on 127.0.0.1:54321');}
export function sql(query:string) {
 const r=spawnSync(process.execPath,['scripts/run-supabase.mjs','db','query','--local',query],{encoding:'utf8'});
 if(r.status!==0)throw new Error('Local database operation failed: '+(r.stderr||r.stdout).slice(0,1500));
}
