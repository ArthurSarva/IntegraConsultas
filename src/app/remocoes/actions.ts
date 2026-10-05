'use server';
import {redirect} from 'next/navigation';
import {revalidatePath} from 'next/cache';
import {patientWorkspace} from '@/lib/patients';
import {devWorkspace} from '@/lib/dev';
import {teamWorkspace} from '@/lib/team';
import type {FormState} from '@/components/form';
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
function input(data:FormData){
 const id=String(data.get('target')??''),operation=String(data.get('operation')??''),version=Number(data.get('version'));
 return uuid.test(id)&&uuid.test(operation)&&Number.isInteger(version)&&version>0?{id,operation,version}:null;
}
export async function deletePatient(_state:FormState,data:FormData):Promise<FormState>{
 const {client,clinic,permissions}=await patientWorkspace();
 if(permissions.scope!=='clinic'||!permissions.can_write)return {error:'Seu perfil não permite excluir pacientes.'};
 if(String(data.get('clinic')??'')!==clinic.id)return {error:'A clínica ativa mudou. Atualize a página.'};
 const value=input(data);if(!value||data.get('confirm')!=='on')return {error:'Confira o cadastro e confirme a ação.'};
 const result=await client.rpc('delete_patient',{clinic_id:clinic.id,patient_id:value.id,expected_version:value.version,operation_id:value.operation});
 if(result.error)return {error:'Não foi possível excluir. Confira seu acesso e atualize o cadastro.'};
 if(result.data.status==='conflict')return {error:'Este cadastro foi alterado. Atualize a página e confira os dados antes de excluir.'};
 if(!['deleted','archived'].includes(result.data.status))return {error:'Não foi possível concluir a ação.'};
 revalidatePath('/pacientes');revalidatePath('/meus-pacientes');revalidatePath('/pacientes/'+value.id);revalidatePath('/meus-pacientes/'+value.id);
 redirect('/pacientes?removido='+result.data.status);
}
export async function removeClinicMember(_state:FormState,data:FormData):Promise<FormState>{
 const kind=String(data.get('kind')??'');
 if(!['administrator','team'].includes(kind))return {error:'Atualize a página antes de continuar.'};
 const {client,clinic,profile}=kind==='administrator'?await devWorkspace():await teamWorkspace();
 if(kind==='team'&&(profile.is_dev||!clinic.roles.some(r=>r.role==='administrator')))return {error:'Somente a administração da clínica pode remover médicos e recepção.'};
 if(String(data.get('clinic')??'')!==clinic.id)return {error:'A clínica ativa mudou. Atualize a página.'};
 const value=input(data);if(!value||data.get('confirm')!=='on')return {error:'Confira a pessoa e confirme a ação.'};
 const result=await client.rpc('remove_clinic_member',{clinic_id:clinic.id,user_id:value.id,member_kind:kind,expected_version:value.version,operation_id:value.operation});
 if(result.error)return {error:'Não foi possível remover. Confira seu acesso e atualize a página.'};
 if(result.data.status==='self')return {error:'Você não pode remover seu próprio acesso.'};
 if(result.data.status!=='removed')return {error:'Este vínculo foi alterado. Atualize a página antes de continuar.'};
 revalidatePath('/equipe');revalidatePath('/dev/administradores');revalidatePath('/inicio');
 return {message:'Acesso removido somente desta clínica. Outros vínculos e o histórico foram preservados.'};
}
