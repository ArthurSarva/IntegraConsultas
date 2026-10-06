import {createClient} from 'npm:@supabase/supabase-js@2.117.2';
import {secretEqual} from '../../../src/lib/google-core.ts';
import {googleCycle} from '../../../scripts/google-cycle.mjs';
const headers={'Content-Type':'application/json','Cache-Control':'no-store'};
Deno.serve(async(request:Request)=>{
 const secret=Deno.env.get('GOOGLE_WORKER_SECRET');
 if(request.method!=='POST')return new Response('{}',{status:405,headers});
 if(!secret||!secretEqual(request.headers.get('X-Worker-Secret')??'',secret))return new Response('{}',{status:401,headers});
 const clientId=Deno.env.get('GOOGLE_CLIENT_ID'),clientSecret=Deno.env.get('GOOGLE_CLIENT_SECRET'),key=Deno.env.get('GOOGLE_TOKEN_ENCRYPTION_KEY');
 if(!clientId||!clientSecret||!key)return new Response('{}',{status:503,headers});
 try{
  const client=createClient(Deno.env.get('SUPABASE_URL')!,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{db:{schema:'api'},auth:{persistSession:false,autoRefreshToken:false}});
  const processed=await googleCycle(client,{clientId,clientSecret,key});return new Response(JSON.stringify({processed}),{headers});
 }catch{return new Response('{}',{status:503,headers});}
});
