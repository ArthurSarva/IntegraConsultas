import {test} from 'node:test';
import assert from 'node:assert/strict';
import {GoogleProvider,eventId,GoogleFailure,renewGoogle} from '../src/lib/google-provider.ts';
const input={clinic:'clinic-a',membership:'doctor-a',appointment:'appointment-a',version:2,calendar:'calendar@example.invalid',start:'2030-01-01T12:00:00Z',end:'2030-01-01T12:30:00Z',status:'agendada'};
function mock(responses){const calls=[];const fetch=async(url,init)=>{calls.push({url,init});const value=responses.shift();assert.ok(value,'Unexpected request');return new Response(JSON.stringify(value.body??{}),{status:value.status??200});};return {fetch,calls};}
test('stable event IDs differ across clinics and payload contains no patient or invite',async()=>{
 assert.equal(eventId('a','b'),eventId('a','b'));assert.notEqual(eventId('a','b'),eventId('c','b'));assert.match(eventId('a','b'),/^[0-9a-v]{5,1024}$/);
 const m=mock([{status:404},{body:{items:[]}},{body:{}}]);await new GoogleProvider('synthetic',m.fetch).sync(input,async()=>true);
 const body=JSON.parse(m.calls[2].init.body);assert.equal(body.summary,'Consulta · IntegraConsultas');assert.equal(body.visibility,'private');assert.equal(body.attendees,undefined);assert.equal(body.description,undefined);assert.deepEqual(body.reminders,{useDefault:false});assert.equal(body.id,eventId(input.clinic,input.appointment));
});
test('Google conflict preserves consultation and performs no external write',async()=>{
 const m=mock([{status:404},{body:{items:[{id:'busy',status:'confirmed'}]}}]);await assert.rejects(()=>new GoogleProvider('synthetic',m.fetch).sync(input,async()=>true),e=>e instanceof GoogleFailure&&e.outcome==='google_conflict');assert.equal(m.calls.length,2);
});
test('own event excluded, update uses ETag and stale lease blocks a write',async()=>{
 const existing={id:eventId(input.clinic,input.appointment),etag:'etag-1',extendedProperties:{private:{integraconsultas:eventId(input.clinic,input.appointment),version:'1'}}};
 const m=mock([{body:existing},{body:{items:[existing]}},{body:{}}]);await new GoogleProvider('synthetic',m.fetch).sync(input,async()=>true);assert.equal(m.calls[2].init.method,'PATCH');assert.equal(m.calls[2].init.headers['If-Match'],'etag-1');
 const stale=mock([{status:404},{body:{items:[]}}]);await assert.rejects(()=>new GoogleProvider('synthetic',stale.fetch).sync(input,async()=>false),e=>e.outcome==='transient_failure');assert.equal(stale.calls.length,2);
});
test('cancellation is idempotent and does not remove unrelated events',async()=>{
 const m=mock([{status:404}]);await new GoogleProvider('synthetic',m.fetch).sync({...input,status:'cancelada'},async()=>true);assert.equal(m.calls.length,1);
 const unrelated=mock([{body:{etag:'x',extendedProperties:{private:{integraconsultas:'other'}}}}]);await assert.rejects(()=>new GoogleProvider('synthetic',unrelated.fetch).sync({...input,status:'cancelada'},async()=>true),e=>e.outcome==='permanent_failure');assert.equal(unrelated.calls.length,1);
 const owned=mock([{body:{etag:'x',extendedProperties:{private:{integraconsultas:eventId(input.clinic,input.appointment)}}}},{status:200}]);await new GoogleProvider('synthetic',owned.fetch).sync({...input,status:'cancelada'},async()=>true);assert.equal(owned.calls[1].init.method,'DELETE');
});
test('pagination checks all events; transparent and cancelled events do not block',async()=>{
 const m=mock([{body:{items:[{id:'a',transparency:'transparent'},{id:'b',status:'cancelled'}],nextPageToken:'page2'}},{body:{items:[{id:'busy'}]}}]);assert.equal(await new GoogleProvider('synthetic',m.fetch).busy(input.calendar,input.start,input.end),true);assert.match(m.calls[1].url,/pageToken=page2/);
});
test('retry errors, revoked tokens, duplicate insert and newer version are handled',async()=>{
 for(const status of [429,500,412]){const m=mock([{status}]);await assert.rejects(()=>new GoogleProvider('synthetic',m.fetch).sync(input,async()=>true),e=>e.outcome==='transient_failure');}
 const revoked=mock([{status:400}]);await assert.rejects(()=>renewGoogle('id','secret','refresh',revoked.fetch),e=>e.outcome==='integration_not_configured');
 const duplicate=mock([{status:404},{body:{items:[]}},{status:409}]);await assert.rejects(()=>new GoogleProvider('synthetic',duplicate.fetch).sync(input,async()=>true),e=>e.outcome==='transient_failure');
 const newer=mock([{body:{extendedProperties:{private:{integraconsultas:eventId(input.clinic,input.appointment),version:'3'}}}}]);await new GoogleProvider('synthetic',newer.fetch).sync(input,async()=>true);assert.equal(newer.calls.length,1);
});
