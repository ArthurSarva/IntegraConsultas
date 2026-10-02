import {createClient} from 'npm:@supabase/supabase-js@2.117.2';
const headers={'Content-Type':'application/json','Cache-Control':'private, no-store'};
const reply=(status:number,message:string,extra:Record<string,unknown>={})=>new Response(JSON.stringify({message,...extra}),{status,headers});
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
async function payload(req:Request){
 const reader=req.body?.getReader();if(!reader)throw new Error('body');
 let size=0;const chunks:Uint8Array[]=[];
 for(;;){const {done,value}=await reader.read();if(done)break;size+=value.length;if(size>4096){await reader.cancel();throw new Error('size');}chunks.push(value);}
 const bytes=new Uint8Array(size);let pos=0;for(const c of chunks){bytes.set(c,pos);pos+=c.length;}
 return JSON.parse(new TextDecoder().decode(bytes));
}
Deno.serve(async(req:Request)=>{
 if(req.method!=='POST')return reply(405,'Método não permitido.');
 const auth=req.headers.get('Authorization')??'';
 if(!/^Bearer [A-Za-z0-9._~-]+$/.test(auth))return reply(401,'Acesso indisponível.');
 try{
  const url=Deno.env.get('SUPABASE_URL')!,key=Deno.env.get('SUPABASE_ANON_KEY')!;
  const userClient=createClient(url,key,{db:{schema:'api'},global:{headers:{Authorization:auth}},auth:{persistSession:false,autoRefreshToken:false}});
  // getUser validates the bearer with Auth. SQL then checks live session, Dev and aal2.
  const verified=await userClient.auth.getUser(auth.slice(7));
  if(verified.error||!verified.data.user)return reply(401,'Acesso indisponível.');
  const body=await payload(req);
  const clinic=String(body.clinic_id??''),operation=String(body.operation_id??'');
  const email=String(body.email??'').trim().toLowerCase(),name=String(body.display_name??'').trim();
  if(!uuid.test(clinic)||!uuid.test(operation)||name.length<1||name.length>120||email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))return reply(400,'Confira nome, email e clínica.');
  const guard=await userClient.rpc('dev_clinic_context',{clinic_id:clinic});
  if(guard.error||guard.data!==clinic)return reply(403,'Acesso indisponível.');
  const lookup=await userClient.rpc('administrator_candidate',{clinic_id:clinic,email});
  if(lookup.error)return reply(403,'Não foi possível cadastrar esta conta.');
  let userId=lookup.data?.id as string|undefined,hash:string|undefined;
  if(!lookup.data?.confirmed){
   // Administrative credential stays in this function and is used only against Auth.
   const admin=createClient(url,Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!,{auth:{persistSession:false,autoRefreshToken:false}});
   const generated=await admin.auth.admin.generateLink({type:'invite',email});
   if(generated.error||!generated.data.user||!generated.data.properties?.hashed_token)return reply(409,'Não foi possível gerar o convite. Confira a conta e tente novamente.');
   userId=generated.data.user.id;hash=generated.data.properties.hashed_token;
  }
  if(!userId)return reply(409,'Não foi possível cadastrar esta conta.');
  // Recheck context and authorization at the atomic domain write, after external Auth.
  const linked=await userClient.rpc('link_administrator',{clinic_id:clinic,user_id:userId,email,display_name:name,operation_id:operation});
  if(linked.error)return reply(409,'O vínculo não foi concluído. Confira sua clínica ativa e tente novamente.');
  // No tokens in logs, DB/audit or error bodies. Nothing is sent by email.
  return reply(200,hash?'Administrador vinculado. Entregue o convite somente ao destinatário.':'Conta existente vinculada. O administrador pode usar sua senha atual.',hash?{invite_hash:hash}:{});
 }catch{return reply(400,'Não foi possível concluir o cadastro. Tente novamente.');}
});

