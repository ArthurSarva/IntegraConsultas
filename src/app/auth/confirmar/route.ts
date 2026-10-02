import {NextResponse,type NextRequest} from 'next/server';
import {createClient} from '@/lib/supabase/server';
import {appOrigin} from '@/lib/config';
export async function GET(request:NextRequest) {
  const url=request.nextUrl; const code=url.searchParams.get('code');
  const token=url.searchParams.get('token_hash'); const type=url.searchParams.get('type');
  const client=await createClient();
  const result=code?await client.auth.exchangeCodeForSession(code)
    :token && (type==='invite'||type==='recovery')?await client.auth.verifyOtp({token_hash:token,type})
    :{error:true};
  const response=NextResponse.redirect(new URL(result.error?'/link-invalido':'/definir-senha',appOrigin()));
  response.headers.set('Cache-Control','private, no-store');
  response.headers.set('Referrer-Policy','no-referrer');
  return response;
}
