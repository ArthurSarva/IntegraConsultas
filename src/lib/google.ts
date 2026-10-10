import 'server-only';
import {createClient as technicalClient} from '@supabase/supabase-js';
import {cookies} from 'next/headers';
import {redirect} from 'next/navigation';
import {workspace} from '@/lib/identity';
import {appOrigin,supabaseConfig} from '@/lib/config';
import {GOOGLE_SCOPES,ownedCalendars,unseal} from '@/lib/google-core';
export const GOOGLE_COOKIE='integraconsultas-google-oauth';
export const GOOGLE_PENDING_COOKIE='integraconsultas-google-pending';
export const GOOGLE_COOKIE_PATH='/integracoes/google';
export function googleConfig(){
 const clientId=process.env.GOOGLE_CLIENT_ID,clientSecret=process.env.GOOGLE_CLIENT_SECRET,key=process.env.GOOGLE_TOKEN_ENCRYPTION_KEY;
 if(!clientId||!clientSecret||!key||!/^[a-f0-9]{64}$/i.test(key)||!process.env.SUPABASE_SERVICE_ROLE_KEY)throw new Error('Google integration is not configured');
 return {clientId,clientSecret,key,redirectUri:appOrigin()+'/integracoes/google/retorno'};
}
export function googleConfigured(){try{googleConfig();return true;}catch{return false;}}
export function googleTechnical(){
 const key=process.env.SUPABASE_SERVICE_ROLE_KEY;if(!key)throw new Error('Technical access is not configured');
 return technicalClient(supabaseConfig().url,key,{db:{schema:'api'},auth:{persistSession:false,autoRefreshToken:false},global:{fetch:(input,init)=>fetch(input,{...init,cache:'no-store'})}});
}
export async function googleWorkspace(){
 const ctx=await workspace();const response=await ctx.client.rpc('agenda_permissions',{clinic_id:ctx.clinic.id});
 if(response.error||!response.data?.doctor_membership)redirect('/inicio');
 return {...ctx,membership:String(response.data.doctor_membership)};
}
export type OAuthContext={state:string;verifier:string;user:string;clinic:string;membership:string;session:string;expires:number};
export type PendingContext=Omit<OAuthContext,'state'|'verifier'>&{proof:string;refresh:string};
export async function readPending(ctx:Awaited<ReturnType<typeof googleWorkspace>>){
 const value=(await cookies()).get(GOOGLE_PENDING_COOKIE)?.value;if(!value)return null;
 try{
  const pending=unseal<PendingContext>(value,googleConfig().key,'google-pending');
  if(pending.user!==ctx.user.id||pending.clinic!==ctx.clinic.id||pending.membership!==ctx.membership||pending.expires<Date.now())return null;
  // Revalidate the same live authentication session, including MFA and clinic context.
  const claims=await ctx.client.auth.getClaims();if(claims.error||claims.data?.claims.session_id!==pending.session)return null;
  return pending;
 }catch{return null;}
}
async function googleFetch(url:string,options:RequestInit){
 const response=await fetch(url,{...options,cache:'no-store',signal:AbortSignal.timeout(12000)});
 if(!response.ok)throw new Error('Google request failed');return response;
}
export async function exchangeCode(code:string,verifier:string){
 const config=googleConfig();
 const response=await googleFetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},
  body:new URLSearchParams({client_id:config.clientId,client_secret:config.clientSecret,code,code_verifier:verifier,redirect_uri:config.redirectUri,grant_type:'authorization_code'})});
 const result=await response.json() as {access_token?:string;refresh_token?:string;scope?:string};
 if(!result.access_token||!result.refresh_token||result.refresh_token.length>1024||!GOOGLE_SCOPES.every(scope=>result.scope?.split(' ').includes(scope)))throw new Error('Incomplete Google authorization');
 return {access:result.access_token,refresh:result.refresh_token};
}
export async function refreshAccess(refresh:string){
 const config=googleConfig();
 const response=await googleFetch('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},
  body:new URLSearchParams({client_id:config.clientId,client_secret:config.clientSecret,refresh_token:refresh,grant_type:'refresh_token'})});
 const result=await response.json() as {access_token?:string};if(!result.access_token)throw new Error('Invalid Google renewal');return result.access_token;
}
export async function listCalendars(access:string){
 const result=[];let page:string|undefined;
 // Fetch all pages, bounded to prevent a provider response from exhausting the server.
 for(let index=0;index<10;index++){
  const url=new URL('https://www.googleapis.com/calendar/v3/users/me/calendarList');url.searchParams.set('maxResults','250');if(page)url.searchParams.set('pageToken',page);
  const response=await googleFetch(url.toString(),{headers:{Authorization:'Bearer '+access}});
  const data=await response.json();result.push(...ownedCalendars(data));page=data.nextPageToken;if(!page)return result;
 }
 throw new Error('Calendar list exceeds limit');
}
