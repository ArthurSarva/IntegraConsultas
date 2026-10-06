// Disposable local Auth accounts only. Never run against the hosted project.
import {spawnSync} from 'node:child_process';
import {writeFile} from 'node:fs/promises';
import {randomUUID,randomBytes} from 'node:crypto';
import {createClient} from '@supabase/supabase-js';
const status=spawnSync(process.execPath,['scripts/run-supabase.mjs','status','-o','env'],{encoding:'utf8'});
if(status.status!==0)throw new Error('Start disposable local Supabase first');
const vars={};
for(const line of status.stdout.split('\n')){
 const match=line.match(/^([A-Z_]+)=(.*)$/);
 if(match)vars[match[1]]=match[2].replace(/^["']|["']$/g,'');
}
const url=vars.API_URL;
if(!url||new URL(url).origin!=='http://127.0.0.1:54321')throw new Error('Fixtures are restricted to disposable local Supabase');
// Pause the disposable scheduler so browser assertions control exactly when work occurs.
const pause=spawnSync(process.execPath,['scripts/run-supabase.mjs','db','query','--local',"do $pause$ begin if to_regclass('cron.job') is not null then execute 'select cron.alter_job(job_id := jobid, active := false) from cron.job where jobname=''integraconsultas-foundation'''; end if; end $pause$;"],{encoding:'utf8'});
if(pause.status!==0)throw new Error('Could not pause disposable automation scheduler: '+(pause.stderr||pause.stdout).slice(0,1500));
const key=vars.PUBLISHABLE_KEY||vars.ANON_KEY;
const adminKey=vars.SECRET_KEY||vars.SERVICE_ROLE_KEY;
if(!key||!adminKey)throw new Error('Local Supabase keys unavailable');
const client=createClient(url,adminKey,{auth:{persistSession:false,autoRefreshToken:false}});
const password=randomBytes(24).toString('base64url')+'aA1!';
const clinics={a:randomUUID(),b:randomUUID()};
const users={};let queries=[];
for(const role of ['receptionA','receptionB','doctor','administrator','dev','provisioner','existing','unprovisioned']){
 const email='web-'+role.toLowerCase()+'-'+randomUUID()+'@example.invalid';
 const {data,error}=await client.auth.admin.createUser({email,password,email_confirm:true,user_metadata:{is_dev:true}});
 if(error||!data.user)throw new Error('Unable to create disposable Auth identity');
 users[role]={id:data.user.id,email};
 if(role==='unprovisioned'||role==='existing')continue;
 queries.push("insert into app.users(id,display_name,is_dev) values ('"+data.user.id+"','Teste "+role+"',"+(role==='dev'||role==='provisioner')+");");
 if(role==='dev'||role==='provisioner')continue;
 const membership=randomUUID(),clinic=role==='receptionB'?clinics.b:clinics.a;
 queries.push("insert into app.memberships(id,clinic_id,user_id) values ('"+membership+"','"+clinic+"','"+data.user.id+"');");
 const roles=role==='doctor'?[['doctor','own'],['reception','own']]:[[role==='administrator'?'administrator':'reception','clinic']];
 for(const [name,scope] of roles)queries.push("insert into app.membership_roles(clinic_id,membership_id,role,scope) values ('"+clinic+"','"+membership+"','"+name+"','"+scope+"');");
}
queries.unshift("insert into app.clinics(id,name) values ('"+clinics.a+"','Clínica de teste A'),('"+clinics.b+"','Clínica de teste B');");
// The CLI driver uses the extended protocol: provision atomically as one statement.
const r=spawnSync(process.execPath,['scripts/run-supabase.mjs','db','query','--local','do $web_fixture$ begin '+queries.join('\n')+' end $web_fixture$;'],{encoding:'utf8'});
if(r.status!==0)throw new Error('Unable to provision local fixtures: '+(r.stderr||r.stdout).slice(0,1500));
await writeFile('.env.web-fixture.json',JSON.stringify({url,key,adminKey,password,clinics,users}));
await writeFile('.env.test.local','NEXT_PUBLIC_SUPABASE_URL='+url+'\nNEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY='+key+'\nAPP_ORIGIN=http://127.0.0.1:3000\n');
console.log('Disposable web fixtures prepared; no real email was sent.');
