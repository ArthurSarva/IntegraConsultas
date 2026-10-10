import {test} from 'node:test';
import assert from 'node:assert/strict';
import {createHash} from 'node:crypto';
import {seal,unseal,authorizationUrl,stateHash,secretEqual,ownedCalendars,GOOGLE_SCOPES} from '../src/lib/google-core.ts';
const key='ab'.repeat(32);
test('credential encryption authenticates payload, key and clinic binding',()=>{
 const value=seal({refresh:'synthetic-refresh'},key,'clinic:A:doctor:1');
 assert.ok(!value.includes('synthetic-refresh'));
 assert.deepEqual(unseal(value,key,'clinic:A:doctor:1'),{refresh:'synthetic-refresh'});
 assert.notEqual(value,seal({refresh:'synthetic-refresh'},key,'clinic:A:doctor:1'));
 assert.throws(()=>unseal(value,key,'clinic:B:doctor:1'));
 assert.throws(()=>unseal(value,'cd'.repeat(32),'clinic:A:doctor:1'));
 const parts=value.split('.');parts[3]=(parts[3][0]==='A'?'B':'A')+parts[3].slice(1);assert.throws(()=>unseal(parts.join('.'),key,'clinic:A:doctor:1'));
 assert.throws(()=>seal({},'short','test'));assert.throws(()=>unseal('not-a-credential',key,'test'));
});
test('OAuth requires offline consent, state and PKCE without broad calendar administration',()=>{
 const url=new URL(authorizationUrl('client','http://127.0.0.1:3000/integracoes/google/retorno','state','verifier'));
 assert.equal(url.origin,'https://accounts.google.com');assert.equal(url.searchParams.get('state'),'state');
 assert.equal(url.searchParams.get('code_challenge'),createHash('sha256').update('verifier').digest('base64url'));
 assert.equal(url.searchParams.get('code_challenge_method'),'S256');assert.equal(url.searchParams.get('access_type'),'offline');
 assert.ok(url.searchParams.get('prompt').includes('consent'));
 assert.deepEqual(url.searchParams.get('scope').split(' '),GOOGLE_SCOPES);
 assert.ok(!GOOGLE_SCOPES.includes('https://www.googleapis.com/auth/calendar'));
 assert.equal(stateHash('state').length,64);assert.ok(secretEqual('equal','equal'));assert.ok(!secretEqual('equal','other'));assert.ok(!secretEqual('equal','shorter'));
});
test('calendar selection accepts only owned calendars and rejects invalid provider data',()=>{
 assert.deepEqual(ownedCalendars({items:[{id:'own',summary:'Minha agenda',accessRole:'owner'},{id:'shared',summary:'Outra',accessRole:'writer'}]}).map(c=>c.id),['own']);
 assert.throws(()=>ownedCalendars({}));assert.deepEqual(ownedCalendars({items:[]}),[]);
});
