import test from 'node:test';
import assert from 'node:assert/strict';
import {passwordMode,contentSecurityPolicy,transportSecurity} from '../src/lib/security-policy.ts';
const now=2000000000;
const claims=(method,timestamp,aal='aal1')=>({role:'authenticated',aal,amr:[{method,timestamp}]});
test('existing MFA requires recent signed TOTP evidence, not merely aal2 or refreshed JWT',()=>{
 assert.equal(passwordMode(claims('totp',now-300,'aal2'),true,now),'allowed');
 assert.equal(passwordMode({...claims('totp',now-301,'aal2'),iat:now},true,now),'totp');
 assert.equal(passwordMode(claims('password',now,'aal2'),true,now),'totp');
 assert.equal(passwordMode(claims('totp',now,'aal1'),true,now),'totp');
 assert.equal(passwordMode(claims('otp',now),true,now),'totp');
});
test('initial password and recovery require recent verified link when no factor exists',()=>{
 for(const method of ['otp','recovery','invite']){
  assert.equal(passwordMode(claims(method,now-600),false,now),'allowed');
  assert.equal(passwordMode(claims(method,now-601),false,now),'recovery');
 }
 assert.equal(passwordMode(claims('password',now),false,now),'recovery');
});
test('malformed, future and user metadata authentication evidence fail closed',()=>{
 for(const amr of [null,{},[null],[{method:'totp',timestamp:String(now)}],[{method:'totp',timestamp:now+1}]])
  assert.equal(passwordMode({role:'authenticated',aal:'aal2',amr},true,now),'totp');
 assert.equal(passwordMode({role:'authenticated',aal:'aal2',user_metadata:{amr:[{method:'totp',timestamp:now}]}},true,now),'totp');
 assert.equal(passwordMode({...claims('totp',now,'aal2'),is_anonymous:true},true,now),'recovery');
 assert.equal(passwordMode({...claims('totp',now,'aal2'),role:'anon'},true,now),'recovery');
});
test('production CSP blocks script injection, embedding and arbitrary connections',()=>{
 const policy=contentSecurityPolicy('abcdefghijklmnopqrstuv',false,'https://example.invalid');
 assert.match(policy,/script-src 'self' 'nonce-abcdefghijklmnopqrstuv' 'strict-dynamic'/);
 assert.doesNotMatch(policy,/unsafe-eval|script-src[^;]*unsafe-inline|https:|ws:/);
 for(const directive of ["object-src 'none'","base-uri 'none'","form-action 'self'","frame-ancestors 'none'",'upgrade-insecure-requests'])assert.ok(policy.includes(directive));
 assert.throws(()=>contentSecurityPolicy("bad'; default-src *",false,'https://example.invalid'));
});
test('local development supports HMR while production HTTP is not auto-upgraded',()=>{
 const dev=contentSecurityPolicy('abcdefghijklmnopqrstuv',true,'http://127.0.0.1:3000');
 assert.match(dev,/unsafe-eval/);assert.match(dev,/connect-src 'self' ws:\/\/127\.0\.0\.1:3000/);assert.doesNotMatch(dev,/upgrade-insecure/);
 assert.doesNotMatch(contentSecurityPolicy('abcdefghijklmnopqrstuv',false,'http://127.0.0.1:3000'),/unsafe-eval|upgrade-insecure|ws:/);
});
test('HSTS is emitted only for an HTTPS production origin',()=>{
 assert.equal(transportSecurity('https://example.invalid',true),'max-age=31536000');
 assert.equal(transportSecurity('https://example.invalid',false),null);
 assert.equal(transportSecurity('http://127.0.0.1:3000',true),null);
});

