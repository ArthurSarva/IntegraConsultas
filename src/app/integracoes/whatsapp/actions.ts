'use server';
import {redirect} from 'next/navigation';
import {revalidatePath} from 'next/cache';
import {workspace} from '@/lib/identity';
import {patientWorkspace} from '@/lib/patients';
import type {FormState} from '@/components/form';
export async function saveWhatsAppChannel(_state:FormState,data:FormData):Promise<FormState>{
 const ctx=await workspace();if(data.get('clinic')!==ctx.clinic.id)return {error:'A clínica ativa mudou. Atualize a página.'};
 const guard=await ctx.client.rpc('team_clinic_context',{clinic_id:ctx.clinic.id});if(guard.error)redirect('/inicio');
 const version=Number(data.get('version'));if(!Number.isSafeInteger(version)||version<0)return {error:'Atualize a configuração.'};
 const result=await ctx.client.rpc('configure_whatsapp_channel',{clinic_id:ctx.clinic.id,expected_version:version,phone:String(data.get('phone')??'').trim(),phone_number_id:String(data.get('phone_id')??'').trim()||null,waba_id:String(data.get('waba')??'').trim()||null,channel_status:String(data.get('status')??'draft')});
 if(result.error)return {error:'Confira o número internacional e os identificadores. A configuração não foi salva.'};
 if(result.data.status==='conflict')return {error:'Outra pessoa alterou a configuração. Atualize a página antes de salvar.'};
 revalidatePath('/integracoes/whatsapp');redirect('/integracoes/whatsapp?salvo=1');
}
export async function saveWhatsAppPreference(_state:FormState,data:FormData):Promise<FormState>{
 const own=data.get('own')==='on',ctx=await patientWorkspace(own),id=String(data.get('patient')??''),version=Number(data.get('version'));
 if(data.get('clinic')!==ctx.clinic.id||!ctx.permissions.can_write||!/^[0-9a-f-]{36}$/i.test(id)||!Number.isSafeInteger(version)||version<1)return {error:'Atualize o cadastro antes de salvar.'};
 const result=await ctx.client.rpc('set_patient_whatsapp',{clinic_id:ctx.clinic.id,patient_id:id,expected_version:version,enabled:data.get('enabled')==='on',own_only:own});
 if(result.error)return {error:'Não foi possível salvar a preferência nesta clínica.'};
 if(result.data.status==='conflict')return {error:'A preferência mudou. Atualize a página.'};
 revalidatePath((own?'/meus-pacientes/':'/pacientes/')+id);return {message:'Preferência registrada. Os envios continuam desativados.'};
}

