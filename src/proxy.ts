import {createServerClient} from '@supabase/ssr';
import {NextResponse,type NextRequest} from 'next/server';
import {appOrigin,supabaseConfig} from '@/lib/config';
import {randomBytes} from 'node:crypto';
import {contentSecurityPolicy} from '@/lib/security-policy';
export async function proxy(request:NextRequest) {
  const nonce=randomBytes(16).toString('base64url');
  const policy=contentSecurityPolicy(nonce,process.env.NODE_ENV==='development',appOrigin());
  const requestHeaders=new Headers(request.headers);
  requestHeaders.set('x-nonce',nonce);requestHeaders.set('Content-Security-Policy',policy);
  let response=NextResponse.next({request:{headers:requestHeaders}});
  const finish=()=>{response.headers.set('Content-Security-Policy',policy);response.headers.set('Cache-Control','private, no-store');return response;};
  if (!process.env.NEXT_PUBLIC_SUPABASE_URL || !process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY) return finish();
  const {url,key}=supabaseConfig();
  const client=createServerClient(url,key,{cookieOptions:{httpOnly:true,sameSite:'lax',secure:process.env.APP_ORIGIN?.startsWith('https://')??false},cookies:{
    getAll:()=>request.cookies.getAll(),
    setAll:(items,headers)=>{
      for (const {name,value} of items) request.cookies.set(name,value);
      requestHeaders.set('cookie',request.cookies.toString());
      response=NextResponse.next({request:{headers:requestHeaders}});
      for (const {name,value,options} of items) response.cookies.set(name,value,options);
      for (const [name,value] of Object.entries(headers)) response.headers.set(name,value);
    }
  }});
  await client.auth.getClaims();
  return finish();
}
export const config={matcher:['/((?!_next/static|_next/image|favicon.ico|.*\\.(?:svg|png|jpg|jpeg|gif|webp)$).*)']};

