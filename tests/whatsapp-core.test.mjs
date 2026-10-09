import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createHmac} from 'node:crypto';
import {DormantMetaWhatsApp,buildWhatsAppTemplate,verifyWhatsAppSignature,parseWhatsAppReceipts} from '../src/lib/whatsapp-core.ts';
const secret='synthetic-webhook-secret';
const payload={object:'whatsapp_business_account',entry:[{id:'123456',changes:[{field:'messages',value:{messaging_product:'whatsapp',metadata:{phone_number_id:'654321'},statuses:[{id:'wamid.synthetic123',status:'delivered',timestamp:'1791240000',recipient_id:'12025550187'}]}}]}]};
const encode=value=>Buffer.from(JSON.stringify(value));
const signature=body=>'sha256='+createHmac('sha256',secret).update(body).digest('hex');
test('adapter is always blocked and never performs an external request',async()=>{
 const previous=globalThis.fetch;globalThis.fetch=()=>{throw Error('Unexpected network request');};
 try{assert.deepEqual(await new DormantMetaWhatsApp().send({to:'+12025550187',template:'consulta_lembrete',language:'pt_BR',date:'10/10/2026',time:'09:00'}),{status:'blocked',reason:'activation_pending'});}finally{globalThis.fetch=previous;}
});
test('template contains only recipient and minimal schedule parameters',()=>{
 const message=buildWhatsAppTemplate({to:'+12025550187',template:'consulta_lembrete',language:'pt_BR',date:'10/10/2026',time:'09:00'});
 assert.equal(message.to,'12025550187');assert.equal(message.type,'template');assert.deepEqual(message.template.components[0].parameters,[{type:'text',text:'10/10/2026'},{type:'text',text:'09:00'}]);
 assert.throws(()=>buildWhatsAppTemplate({to:'not-a-number',template:'consulta_lembrete',language:'pt_BR',date:'10/10/2026',time:'09:00'}));
});
test('raw body authentication rejects tampering, missing secret and excessive size',()=>{
 const body=encode(payload);assert.equal(verifyWhatsAppSignature(body,signature(body),secret),true);
 assert.equal(verifyWhatsAppSignature(Buffer.concat([body,Buffer.from(' ')]),signature(body),secret),false);
 assert.equal(verifyWhatsAppSignature(body,signature(body),''),false);assert.equal(verifyWhatsAppSignature(Buffer.alloc(262145),signature(body),secret),false);
 assert.throws(()=>parseWhatsAppReceipts(body,'sha256='+ '0'.repeat(64),secret));
});
test('receipt fingerprint is stable and cannot retain recipient or message content',()=>{
 const body=encode(payload),r=parseWhatsAppReceipts(body,signature(body),secret)[0];
 assert.equal(r.status,'delivered');assert.equal(r.phoneNumberId,'654321');assert.equal(r.hash.length,64);
 assert.equal(r.hash,parseWhatsAppReceipts(body,signature(body),secret)[0].hash);assert.equal(JSON.stringify(r).includes('12025550187'),false);
 const changed=structuredClone(payload);changed.entry[0].changes[0].value.statuses[0].status='read';const b=encode(changed);
 assert.notEqual(r.hash,parseWhatsAppReceipts(b,signature(b),secret)[0].hash);
});
test('malformed, oversized and unrelated webhook objects are rejected',()=>{
 for(const mutate of [v=>{v.object='other';},v=>{v.entry[0].changes[0].value.statuses[0].status='prepared';},v=>{v.entry[0].changes[0].value.metadata.phone_number_id='invalid';},v=>{v.entry=Array(21).fill(v.entry[0]);}]){
  const value=structuredClone(payload);mutate(value);const body=encode(value);assert.throws(()=>parseWhatsAppReceipts(body,signature(body),secret));
 }
});

