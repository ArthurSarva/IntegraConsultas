'use server';
import {randomBytes} from 'node:crypto';
import {cookies} from 'next/headers';
import {redirect} from 'next/navigation';
import {revalidatePath} from 'next/cache';
import {appOrigin} from '@/lib/config';
import {authorizationUrl,seal,stateHash} from '@/lib/google-core';
import {GOOGLE_COOKIE,GOOGLE_PENDING_COOKIE,GOOGLE_COOKIE_PATH,googleConfig,googleWorkspace,googleTechnical,readPending,listCalendars,refreshAccess} from '@/lib/google';
export async function connectGoogle(data:FormData){
 const ctx=await googleWorkspace();if(data.get('clinic')!==ctx.clinic.id)redirect('/integracoes/google?erro=contexto');
 const config=googleConfig(),state=randomBytes(32).toString('base64url'),verifier=randomBytes(32).toString('base64url');
 const result=await ctx.client.rpc('google_begin',{clinic_id:ctx.clinic.id,state_hash:stateHash(state)});
 if(result.error)redirect('/integracoes/google?erro=inicio');
 const store=await cookies();store.set(GOOGLE_PENDING_COOKIE,'',{httpOnly:true,secure:appOrigin().startsWith('https:'),sameSite:'lax',path:GOOGLE_COOKIE_PATH,maxAge:0});
 store.set(GOOGLE_COOKIE,seal({state,verifier,user:ctx.user.id,clinic:ctx.clinic.id,membership:ctx.membership,session:result.data.session,expires:Date.now()+600000},config.key,'google-oauth'),
  {httpOnly:true,secure:appOrigin().startsWith('https:'),sameSite:'lax',path:GOOGLE_COOKIE_PATH,maxAge:600});
 redirect(authorizationUrl(config.clientId,config.redirectUri,state,verifier));
}
export async function selectGoogleCalendar(data:FormData){
 const ctx=await googleWorkspace(),pending=await readPending(ctx);
 if(data.get('clinic')!==ctx.clinic.id||!pending)redirect('/integracoes/google?erro=expirado');
 let calendar;try{calendar=(await listCalendars(await refreshAccess(pending.refresh))).find(item=>item.id===data.get('calendar'));}catch{redirect('/integracoes/google?erro=google');}
 if(!calendar)redirect('/integracoes/google?erro=agenda');
 const result=await googleTechnical().rpc('google_save',{clinic_id:ctx.clinic.id,membership_id:ctx.membership,proof:pending.proof,
  credential:seal({refresh:pending.refresh},googleConfig().key,'google-token:'+ctx.clinic.id+':'+ctx.membership),calendar_id:calendar.id,calendar_name:calendar.summary});
 if(result.error)redirect('/integracoes/google?erro=salvar');
 (await cookies()).set(GOOGLE_PENDING_COOKIE,'',{httpOnly:true,sameSite:'lax',secure:appOrigin().startsWith('https:'),path:GOOGLE_COOKIE_PATH,maxAge:0});
 revalidatePath('/integracoes/google');redirect('/integracoes/google?conectado=1');
}
export async function disconnectGoogle(data:FormData){
 const ctx=await googleWorkspace();if(data.get('clinic')!==ctx.clinic.id||data.get('confirm')!=='on')redirect('/integracoes/google?erro=confirmacao');
 const result=await ctx.client.rpc('google_disconnect',{clinic_id:ctx.clinic.id});if(result.error)redirect('/integracoes/google?erro=salvar');
 const store=await cookies();for(const name of [GOOGLE_COOKIE,GOOGLE_PENDING_COOKIE])store.set(name,'',{httpOnly:true,sameSite:'lax',secure:appOrigin().startsWith('https:'),path:GOOGLE_COOKIE_PATH,maxAge:0});
 revalidatePath('/integracoes/google');redirect('/integracoes/google?desconectado=1');
}
