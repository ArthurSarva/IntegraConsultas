'use server';
import {revalidatePath} from 'next/cache';
import {teamWorkspace} from '@/lib/team';import {appOrigin} from '@/lib/config';import type {FormState} from '@/components/form';
export async function configureAdministratorDoctor(_state:FormState,data:FormData):Promise<FormState>{
 const {client,clinic,profile}=await teamWorkspace();
 if(profile.is_dev||!clinic.roles.some(r=>r.role==='administrator'))return {error:'Esta opção é exclusiva do administrador da clínica.'};
 if(String(data.get('clinic')??'')!==clinic.id)return {error:'A clínica ativa mudou. Atualize a página antes de continuar.'};
 const duration=Number(data.get('duration'));
 const enabled=data.get('doctor')==='on',operation=String(data.get('operation')??'');
 if((enabled&&![15,30,45,60].includes(duration))||!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(operation))return {error:'Confira o perfil de médico e a duração selecionada.'};
 const result=enabled
  ?await client.rpc('configure_administrator_doctor',{clinic_id:clinic.id,duration_minutes:duration,operation_id:operation})
  :await client.rpc('disable_administrator_doctor',{clinic_id:clinic.id,operation_id:operation});
 if(result.error)return {error:'Não foi possível salvar. Confira sua clínica ativa e tente novamente.'};
 revalidatePath('/equipe');revalidatePath('/inicio');revalidatePath('/meus-pacientes');
 return {message:enabled?'Perfil de médico e duração salvos nesta clínica. Seu acesso administrativo foi mantido.':'Perfil de médico desativado nesta clínica. Seu acesso administrativo foi mantido.'};
}
export async function provisionTeamMember(_state:FormState,data:FormData):Promise<FormState>{
 const {client,clinic}=await teamWorkspace();
 const origin=appOrigin();
 if(String(data.get('clinic')??'')!==clinic.id)return {error:'A clínica ativa mudou. Atualize a página antes de continuar.'};
 const name=String(data.get('name')??'').trim(),email=String(data.get('email')??'').trim(),role=String(data.get('role')??'');
 const reception=data.get('reception')==='on',duration=role==='doctor'?Number(data.get('duration')):null;
 if(name.length<1||name.length>120||email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)
  ||!['doctor','reception'].includes(role)||(role==='doctor'&&![15,30,45,60].includes(duration!))||(role==='reception'&&reception))return {error:'Confira nome, email, função e duração.'};
 const result=await client.functions.invoke('provision-team',{body:{clinic_id:clinic.id,display_name:name,email,team_role:role,with_reception:reception,duration_minutes:duration,operation_id:String(data.get('operation')??'')}});
 if(result.error)return {error:'Não foi possível cadastrar. Confira a conta, sua clínica ativa e tente novamente.'};
 revalidatePath('/equipe');const hash=result.data.invite_hash as string|undefined;
 return {message:String(result.data.message),inviteUrl:hash?origin+'/convite#token='+encodeURIComponent(hash):undefined};
}
