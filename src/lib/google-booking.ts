import 'server-only';
import {googleTechnical,googleConfig,googleConfigured} from '@/lib/google';
import {GoogleProvider,renewGoogle,eventId} from '@/lib/google-provider';
import {unseal} from '@/lib/google-core';
import type {agendaWorkspace} from '@/lib/agenda';
export async function checkGoogleBooking(ctx:Awaited<ReturnType<typeof agendaWorkspace>>,doctor:string,start:string,duration:number,ignore:string[],operation:string){
 // The user RPC checks clinic, permissions and time conversion without returning credentials.
 const window=await ctx.client.rpc('google_begin_booking',{clinic_id:ctx.clinic.id,doctor_id:doctor,start_local:start,duration_minutes:duration,own_only:ctx.path==='/minha-agenda',operation_id:operation});
 if(window.error)return 'denied';if(!window.data.connected)return 'not_connected';
 let outcome:'free'|'busy'|'unavailable'='unavailable';
 try{
  if(!googleConfigured())throw new Error('Google configuration unavailable');
  const response=await googleTechnical().rpc('google_load_connection',{clinic_id:ctx.clinic.id,doctor_id:doctor});if(response.error||!response.data)throw new Error('Connection unavailable');
  const config=googleConfig(),token=unseal<{refresh:string}>(response.data.credential,config.key,'google-token:'+ctx.clinic.id+':'+doctor);
  const access=await renewGoogle(config.clientId,config.clientSecret,token.refresh);
  outcome=await new GoogleProvider(access).busy(response.data.calendar,window.data.start,window.data.end,ignore.map(id=>eventId(ctx.clinic.id,id)))?'busy':'free';
 }catch{outcome='unavailable';}
 try{const approved=await googleTechnical().rpc('google_approve_booking',{clinic_id:ctx.clinic.id,proof:window.data.proof,outcome});if(approved.error||!approved.data)return 'denied';}catch{return 'denied';}
 return outcome;
}
