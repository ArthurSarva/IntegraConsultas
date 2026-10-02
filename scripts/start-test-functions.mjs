import {spawn} from 'node:child_process';import {openSync,readFileSync} from 'node:fs';
const f=JSON.parse(readFileSync('.env.web-fixture.json','utf8'));
if(f.url!=='http://127.0.0.1:54321')throw new Error('Functions tests require disposable local Supabase');
const fd=openSync('.functions-test.log','a');
const child=spawn(process.execPath,['scripts/run-supabase.mjs','functions','serve'],{detached:true,windowsHide:true,stdio:['ignore',fd,fd]});child.unref();
const deadline=Date.now()+90000;
while(Date.now()<deadline){
 try{const r=await fetch(f.url+'/functions/v1/provision-administrator',{headers:{apikey:f.key}});if(r.status===405){console.log('Guarded local function ready');process.exit(0);}}catch{}
 await new Promise(resolve=>setTimeout(resolve,500));
}
throw new Error('Local function did not become ready; inspect .functions-test.log');

