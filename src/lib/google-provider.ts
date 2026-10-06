import {createHash} from 'node:crypto';
export type SyncInput={clinic:string;membership:string;appointment:string;version:number;calendar:string;start:string;end:string;status:string;replaces?:string|null};
export class GoogleFailure extends Error{outcome:'transient_failure'|'permanent_failure'|'google_conflict'|'integration_not_configured';constructor(outcome:GoogleFailure['outcome']){super(outcome);this.outcome=outcome;}}
export function eventId(clinic:string,appointment:string){return 'ic'+createHash('sha256').update(clinic+':'+appointment).digest('hex');}
export class GoogleProvider{
 private access:string;private transport:typeof fetch;
 constructor(access:string,transport:typeof fetch=fetch){this.access=access;this.transport=transport;}
 private async request(url:string,init:RequestInit={}){
  let r:Response;try{r=await this.transport(url,{...init,headers:{Authorization:'Bearer '+this.access,...init.headers},signal:AbortSignal.timeout(12000),cache:'no-store'});}catch{throw new GoogleFailure('transient_failure');}
  if(r.status===429||r.status>=500||r.status===412)throw new GoogleFailure('transient_failure');
  if(r.status===401)throw new GoogleFailure('integration_not_configured');
  if(r.status===403)throw new GoogleFailure('permanent_failure');return r;
 }
 private base(calendar:string){return 'https://www.googleapis.com/calendar/v3/calendars/'+encodeURIComponent(calendar)+'/events';}
 async busy(calendar:string,start:string,end:string,ignore:string[]=[]){
  let page:string|undefined;
  for(let n=0;n<10;n++){
   const u=new URL(this.base(calendar));u.search=new URLSearchParams({timeMin:start,timeMax:end,singleEvents:'true',showDeleted:'false',maxResults:'250',fields:'nextPageToken,items(id,status,transparency,start,end)',...(page?{pageToken:page}:{})}).toString();
   const r=await this.request(u.toString());if(!r.ok)throw new GoogleFailure('permanent_failure');
   const data=await r.json();if(!Array.isArray(data.items))throw new GoogleFailure('transient_failure');
   if(data.items.some((e:{id:string;status?:string;transparency?:string})=>e.status!=='cancelled'&&e.transparency!=='transparent'&&!ignore.includes(e.id)))return true;
   page=data.nextPageToken;if(!page)return false;
  }throw new GoogleFailure('transient_failure');
 }
 async sync(input:SyncInput,beforeWrite:()=>Promise<boolean>){
  const id=eventId(input.clinic,input.appointment),base=this.base(input.calendar),url=base+'/'+id+'?sendUpdates=none';
  const found=await this.request(url);let existing=null;
  if(found.ok)existing=await found.json();else if(![404,410].includes(found.status))throw new GoogleFailure('permanent_failure');
  if(existing&&existing.status!=='cancelled'&&existing.extendedProperties?.private?.integraconsultas!==id)throw new GoogleFailure('permanent_failure');
  if(existing&&Number(existing.extendedProperties?.private?.version)>input.version)return;
  if(input.status==='cancelada'){
   if(!existing||existing.status==='cancelled')return;
   if(!await beforeWrite())throw new GoogleFailure('transient_failure');
   const r=await this.request(url,{method:'DELETE',headers:{'If-Match':existing.etag}});if(!r.ok&&![404,410].includes(r.status))throw new GoogleFailure('permanent_failure');return;
  }
  if(['agendada','confirmada'].includes(input.status)&&await this.busy(input.calendar,input.start,input.end,[id,...(input.replaces?[eventId(input.clinic,input.replaces)]:[])]))throw new GoogleFailure('google_conflict');
  if(existing?.status==='cancelled')throw new GoogleFailure('permanent_failure');
  if(!await beforeWrite())throw new GoogleFailure('transient_failure');
  const body={...(existing?{}:{id}),summary:'Consulta · IntegraConsultas',visibility:'private',start:{dateTime:input.start},end:{dateTime:input.end},
   reminders:{useDefault:false},extendedProperties:{private:{integraconsultas:id,version:String(input.version)}}};
  const r=await this.request(existing?url:base+'?sendUpdates=none',{method:existing?'PATCH':'POST',headers:{'Content-Type':'application/json',...(existing?{'If-Match':existing.etag}:{})},body:JSON.stringify(body)});
  if(r.status===409)throw new GoogleFailure('transient_failure');if(!r.ok)throw new GoogleFailure('permanent_failure');
 }
}
export async function renewGoogle(clientId:string,clientSecret:string,refresh:string,transport:typeof fetch=fetch){
 let r:Response;try{r=await transport('https://oauth2.googleapis.com/token',{method:'POST',headers:{'Content-Type':'application/x-www-form-urlencoded'},body:new URLSearchParams({client_id:clientId,client_secret:clientSecret,refresh_token:refresh,grant_type:'refresh_token'}),signal:AbortSignal.timeout(12000),cache:'no-store'});}catch{throw new GoogleFailure('transient_failure');}
 if(r.status===429||r.status>=500)throw new GoogleFailure('transient_failure');if(!r.ok)throw new GoogleFailure('integration_not_configured');
 const data=await r.json();if(typeof data.access_token!=='string')throw new GoogleFailure('transient_failure');return data.access_token as string;
}
