import {createHmac,createHash,timingSafeEqual} from 'node:crypto';
import {Buffer} from 'node:buffer';
export type WhatsAppTemplate={to:string;template:string;language:'pt_BR';date:string;time:string};
export type WhatsAppResult={status:'blocked';reason:'activation_pending'};
export interface WhatsAppProvider{send(input:WhatsAppTemplate):Promise<WhatsAppResult>}
// Deliberately no transport or activation flag. Credentials cannot enable this adapter.
export class DormantMetaWhatsApp implements WhatsAppProvider{
 async send(_input:WhatsAppTemplate):Promise<WhatsAppResult>{return {status:'blocked',reason:'activation_pending'};}
}
export function buildWhatsAppTemplate(input:WhatsAppTemplate){
 if(!/^\+[1-9][0-9]{7,14}$/.test(input.to)||!/^[a-z][a-z0-9_]{0,511}$/.test(input.template)||input.language!=='pt_BR'
 ||!/^\d{2}\/\d{2}\/\d{4}$/.test(input.date)||!/^([01]\d|2[0-3]):[0-5]\d$/.test(input.time))throw new Error('Invalid message');
 return {messaging_product:'whatsapp',recipient_type:'individual',to:input.to.slice(1),type:'template',template:{name:input.template,language:{code:input.language},components:[{type:'body',parameters:[{type:'text',text:input.date},{type:'text',text:input.time}]}]}};
}
export function verifyWhatsAppSignature(body:Uint8Array,signature:string,secret:string){
 if(body.byteLength>262144||!secret||secret.length>1024||!/^sha256=[a-f0-9]{64}$/.test(signature))return false;
 const expected=createHmac('sha256',secret).update(body).digest();
 return timingSafeEqual(expected,Buffer.from(signature.slice(7),'hex'));
}
export type WhatsAppReceipt={waba:string;phoneNumberId:string;messageId:string;status:'sent'|'delivered'|'read'|'failed';timestamp:string;hash:string};
// Receipts have no message text, phone recipient, name or diagnostic information.
export function parseWhatsAppReceipts(body:Uint8Array,signature:string,secret:string):WhatsAppReceipt[]{
 if(!verifyWhatsAppSignature(body,signature,secret))throw new Error('Invalid webhook signature');
 const data=JSON.parse(Buffer.from(body).toString('utf8'));
 if(data.object!=='whatsapp_business_account'||!Array.isArray(data.entry)||data.entry.length>20)throw new Error('Invalid webhook');
 const results:WhatsAppReceipt[]=[];
 for(const entry of data.entry){
  if(typeof entry.id!=='string'||!/^\d{5,30}$/.test(entry.id)||!Array.isArray(entry.changes)||entry.changes.length>20)throw new Error('Invalid webhook');
  for(const change of entry.changes){
   if(change.field!=='messages')continue;
   const value=change.value;if(value?.messaging_product!=='whatsapp'||!/^\d{5,30}$/.test(String(value.metadata?.phone_number_id??'')))throw new Error('Invalid webhook');
   if(value.statuses===undefined)continue;
   if(!Array.isArray(value.statuses)||value.statuses.length>100)throw new Error('Invalid webhook');
   for(const status of value.statuses){
    if(typeof status.id!=='string'||status.id.length>256||!/^wamid\.[A-Za-z0-9+/=_-]+$/.test(status.id)||!['sent','delivered','read','failed'].includes(status.status)||typeof status.timestamp!=='string'||!/^\d{1,11}$/.test(status.timestamp))throw new Error('Invalid webhook');
    const instant=new Date(Number(status.timestamp)*1000);if(!Number.isFinite(instant.getTime()))throw new Error('Invalid webhook');
    const receipt={waba:entry.id,phoneNumberId:String(value.metadata.phone_number_id),messageId:status.id,status:status.status as WhatsAppReceipt['status'],timestamp:instant.toISOString()};
    results.push({...receipt,hash:createHash('sha256').update(JSON.stringify(receipt)).digest('hex')});
    if(results.length>100)throw new Error('Webhook exceeds limit');
   }
  }
 }
 return results;
}

