import {NextResponse} from 'next/server';
import {cookies} from 'next/headers';
import {appOrigin} from '@/lib/config';
import {seal,unseal,secretEqual,stateHash} from '@/lib/google-core';
import {GOOGLE_COOKIE,GOOGLE_PENDING_COOKIE,GOOGLE_COOKIE_PATH,googleConfig,googleWorkspace,exchangeCode,type OAuthContext} from '@/lib/google';
export const runtime='nodejs';
export async function GET(request:Request){
 const ctx=await googleWorkspace(),store=await cookies(),params=new URL(request.url).searchParams;
 const finish=(query:string)=>{
  const response=NextResponse.redirect(appOrigin()+'/integracoes/google?'+query,303);
  response.headers.set('Cache-Control','no-store');response.headers.set('Referrer-Policy','no-referrer');
  response.cookies.set(GOOGLE_COOKIE,'',{httpOnly:true,sameSite:'lax',secure:appOrigin().startsWith('https:'),path:GOOGLE_COOKIE_PATH,maxAge:0});return response;
 };
 try{
  const value=store.get(GOOGLE_COOKIE)?.value;if(!value)return finish('erro=expirado');const config=googleConfig();
  const context=unseal<OAuthContext>(value,config.key,'google-oauth');
  const state=params.get('state'),code=params.get('code');
  if(!state||!secretEqual(state,context.state)||context.expires<Date.now()||context.user!==ctx.user.id||context.clinic!==ctx.clinic.id||context.membership!==ctx.membership)return finish('erro=contexto');
  const verified=await ctx.client.rpc('google_verify',{clinic_id:ctx.clinic.id,state_hash:stateHash(state)});
  if(verified.error||verified.data.session!==context.session)return finish('erro=expirado');
  if(params.has('error'))return finish('erro=autorizacao');
  if(!code||code.length>4096)return finish('erro=autorizacao');
  const token=await exchangeCode(code,context.verifier);
  const response=finish('selecionar=1');
  response.cookies.set(GOOGLE_PENDING_COOKIE,seal({user:context.user,clinic:context.clinic,membership:context.membership,session:context.session,
   expires:context.expires,proof:verified.data.proof,refresh:token.refresh},config.key,'google-pending'),
   {httpOnly:true,sameSite:'lax',secure:appOrigin().startsWith('https:'),path:GOOGLE_COOKIE_PATH,maxAge:Math.max(1,Math.floor((context.expires-Date.now())/1000))});
  return response;
 }catch{return finish('erro=google');}
}
