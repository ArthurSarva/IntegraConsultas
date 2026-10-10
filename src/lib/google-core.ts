import {createCipheriv,createDecipheriv,createHash,randomBytes,timingSafeEqual} from 'node:crypto';
import {Buffer} from 'node:buffer';

export const GOOGLE_SCOPES=[
 'https://www.googleapis.com/auth/calendar.calendarlist.readonly',
 'https://www.googleapis.com/auth/calendar.events.owned',
 'https://www.googleapis.com/auth/calendar.freebusy',
];
export function stateHash(value:string){return createHash('sha256').update(value).digest('hex');}
export function secretEqual(a:string,b:string){const left=Buffer.from(a),right=Buffer.from(b);return left.length===right.length&&timingSafeEqual(left,right);}
function encryptionKey(key:string){if(!/^[a-f0-9]{64}$/i.test(key))throw new Error('Invalid Google encryption key');return Buffer.from(key,'hex');}
export function seal(value:unknown,key:string,purpose:string){
 const iv=randomBytes(12),cipher=createCipheriv('aes-256-gcm',encryptionKey(key),iv);cipher.setAAD(Buffer.from(purpose));
 const body=Buffer.concat([cipher.update(JSON.stringify(value),'utf8'),cipher.final()]);
 return ['v1',iv.toString('base64url'),cipher.getAuthTag().toString('base64url'),body.toString('base64url')].join('.');
}
export function unseal<T>(value:string,key:string,purpose:string):T{
 const [version,iv,tag,body,...extra]=value.split('.');
 if(version!=='v1'||!iv||!tag||!body||extra.length||value.length>16000)throw new Error('Invalid encrypted credential');
 const decipher=createDecipheriv('aes-256-gcm',encryptionKey(key),Buffer.from(iv,'base64url'));
 decipher.setAAD(Buffer.from(purpose));decipher.setAuthTag(Buffer.from(tag,'base64url'));
 return JSON.parse(Buffer.concat([decipher.update(Buffer.from(body,'base64url')),decipher.final()]).toString('utf8')) as T;
}
export function authorizationUrl(clientId:string,redirectUri:string,state:string,verifier:string){
 const url=new URL('https://accounts.google.com/o/oauth2/v2/auth');
 url.search=new URLSearchParams({client_id:clientId,redirect_uri:redirectUri,response_type:'code',scope:GOOGLE_SCOPES.join(' '),
  state,code_challenge:createHash('sha256').update(verifier).digest('base64url'),code_challenge_method:'S256',
  access_type:'offline',prompt:'consent select_account',include_granted_scopes:'false'}).toString();return url.toString();
}
export type GoogleCalendar={id:string;summary:string;accessRole:string};
export function ownedCalendars(input:unknown):GoogleCalendar[]{
 if(!input||typeof input!=='object'||!Array.isArray((input as {items?:unknown}).items))throw new Error('Invalid calendar response');
 return (input as {items:GoogleCalendar[]}).items.filter(item=>item.accessRole==='owner'&&typeof item.id==='string'&&item.id.length<=1024&&typeof item.summary==='string').map(item=>({...item,summary:item.summary.slice(0,256)||'Agenda Google'}));
}

