type Claims={aal?:unknown;amr?:unknown;sub?:unknown;role?:unknown;is_anonymous?:unknown};
export type PasswordMode='allowed'|'totp'|'recovery';
// Use only verified Auth claims matched to getUser(), never unverified decoded input.
export function passwordMode(claims:Claims,hasTotp:boolean,now=Math.floor(Date.now()/1000)):PasswordMode{
 if(claims.role!=='authenticated'||claims.is_anonymous===true)return 'recovery';
 const recent=(method:string,seconds:number)=>Array.isArray(claims.amr)&&claims.amr.some((entry:unknown)=>{
  if(!entry||typeof entry!=='object')return false;
  const e=entry as {method?:unknown;timestamp?:unknown};
  return e.method===method&&typeof e.timestamp==='number'&&Number.isSafeInteger(e.timestamp)&&now-e.timestamp>=0&&now-e.timestamp<=seconds;
 });
 if(hasTotp)return claims.aal==='aal2'&&recent('totp',300)?'allowed':'totp';
 // verifyOtp issues method=otp for recovery and invitations in Supabase Auth.
 return recent('otp',600)||recent('recovery',600)||recent('invite',600)?'allowed':'recovery';
}
export function contentSecurityPolicy(nonce:string,development:boolean,origin:string){
 if(!/^[A-Za-z0-9_-]{22,64}$/.test(nonce))throw new Error('Invalid nonce');
 const configured=new URL(origin);
 const local=development&&configured.protocol==='http:'&&['127.0.0.1','localhost'].includes(configured.hostname);
 const websocket=local?' '+configured.origin.replace(/^http:/,'ws:'):'';
 return ["default-src 'self'",`script-src 'self' 'nonce-${nonce}' 'strict-dynamic'${development?" 'unsafe-eval'":''}`,
 "style-src 'self' 'unsafe-inline'","img-src 'self' data:","font-src 'self'",`connect-src 'self'${websocket}`,
 "object-src 'none'","base-uri 'none'","form-action 'self'","frame-ancestors 'none'",
 ...(!development&&configured.protocol==='https:'?['upgrade-insecure-requests']:[])].join('; ');
}
export function transportSecurity(origin:string,production:boolean){
 return production&&new URL(origin).protocol==='https:'?'max-age=31536000':null;
}

