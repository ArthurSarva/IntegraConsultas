'use server';
import {redirect} from 'next/navigation';
import {revalidatePath} from 'next/cache';
import {agendaWorkspace,uuid} from '@/lib/agenda';
import type {FormState} from '@/components/form';
import {checkGoogleBooking} from '@/lib/google-booking';
const localTime=/^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}$/;
function version(data:FormData){const value=Number(data.get('version'));return Number.isInteger(value)&&value>0?value:null;}
async function context(data:FormData){
 const own=data.get('own')==='on',result=await agendaWorkspace(own),operation=String(data.get('operation')??'');
 if(data.get('clinic')!==result.clinic.id||!uuid.test(operation))return null;
 return {...result,own,operation};
}
function mutationResult(result:{error:unknown;data:unknown}):FormState|null{
 if(result.error)return {error:'Não foi possível salvar. Confira seu acesso, os dados e a clínica ativa.'};
 const status=(result.data as {status?:string}|null)?.status;
 if(status==='saved')return null;
 return {error:status==='occupied'?'Horário indisponível. Escolha outro intervalo.':status==='unavailable'?'A consulta precisa caber em um horário de atendimento do médico.':status==='conflict'?'Este registro foi alterado. Atualize a página e confira os dados.':status==='too_early'?'Conclusão e falta ficam disponíveis após o horário final da consulta.':'Não foi possível concluir esta operação.'};
}
function refresh(){for(const path of ['/agenda','/minha-agenda']){revalidatePath(path);revalidatePath(path+'/horarios');revalidatePath(path+'/nova');revalidatePath(path+'/[id]','page');}for(const path of ['/pacientes','/meus-pacientes']){revalidatePath(path);revalidatePath(path+'/[id]','page');}revalidatePath('/inicio');}
export async function saveAppointment(_state:FormState,data:FormData):Promise<FormState>{
 const ctx=await context(data);if(!ctx||!ctx.permissions.can_write)return {error:'Seu acesso não permite salvar esta consulta.'};
 const doctor=String(data.get('doctor')??''),patient=String(data.get('patient')??''),start=String(data.get('start')??''),duration=Number(data.get('duration'));
 const appointment=String(data.get('appointment')??''),replace=data.get('replace')==='on'?String(data.get('replacement')??''):'';
 const replacementVersion=replace?Number(data.get('replacement_version')):null;
 if(!uuid.test(doctor)||!uuid.test(patient)||!localTime.test(start)||![15,30,45,60].includes(duration)
  ||(appointment&&(!uuid.test(appointment)||!version(data)))||(replace&&(!uuid.test(replace)||!Number.isInteger(replacementVersion)||(replacementVersion??0)<1)))return {error:'Confira paciente, médico, horário, duração e a consulta que deseja substituir.'};
 const google=await checkGoogleBooking(ctx,doctor,start,duration,[appointment,replace].filter(Boolean),ctx.operation);
 if(google==='denied')return {error:'Não foi possível verificar seu acesso a este horário.'};
 if(google==='busy')return {error:'O Google Agenda mostra um conflito neste horário. Escolha outro intervalo.'};
 const result=await ctx.client.rpc('save_appointment',{clinic_id:ctx.clinic.id,doctor_id:doctor,patient_id:patient,appointment_id:appointment||null,start_local:start,duration_minutes:duration,
  expected_version:appointment?version(data):null,replace_id:replace||null,replace_version:replacementVersion,own_only:ctx.own,operation_id:ctx.operation});
 const failure=mutationResult(result);if(failure)return failure;refresh();redirect(ctx.path+'/'+result.data.id+'?salvo=1'+(google==='unavailable'?'&google=indisponivel':''));
}
export async function changeAppointmentStatus(_state:FormState,data:FormData):Promise<FormState>{
 const ctx=await context(data),appointment=String(data.get('appointment')??''),status=String(data.get('status')??'');
 if(!ctx||!ctx.permissions.can_write||!uuid.test(appointment)||!version(data)||!['confirmada','concluida','cancelada','falta'].includes(status))return {error:'Confira a consulta e a ação selecionada.'};
 if(status==='cancelada'&&data.get('confirm')!=='on')return {error:'Confirme o cancelamento desta consulta.'};
 const result=await ctx.client.rpc('change_appointment_status',{clinic_id:ctx.clinic.id,appointment_id:appointment,next_status:status,expected_version:version(data),own_only:ctx.own,operation_id:ctx.operation});
 const failure=mutationResult(result);if(failure)return failure;refresh();return {message:'Situação da consulta atualizada.'};
}
export async function changeAvailability(_state:FormState,data:FormData):Promise<FormState>{
 const ctx=await context(data),doctor=String(data.get('doctor')??''),window=String(data.get('window')??'');
 if(!ctx||!ctx.permissions.can_write||!uuid.test(doctor)||(window&&(!uuid.test(window)||!version(data)||data.get('confirm')!=='on')))return {error:'Confira o médico e confirme a alteração.'};
 const weekday=Number(data.get('weekday')),start=String(data.get('start')??''),end=String(data.get('end')??'');
 if(!window&&(!Number.isInteger(weekday)||weekday<0||weekday>6||!/^\d{2}:\d{2}$/.test(start)||!/^\d{2}:\d{2}$/.test(end)))return {error:'Confira o dia da semana e os horários.'};
 const result=await ctx.client.rpc('change_availability',{clinic_id:ctx.clinic.id,doctor_id:doctor,window_id:window||null,weekday:window?null:weekday,start_time:window?null:start,end_time:window?null:end,
  expected_version:window?version(data):null,own_only:ctx.own,operation_id:ctx.operation});
 const failure=mutationResult(result);if(failure)return failure;refresh();return {message:window?'Horário retirado. Consultas já registradas foram preservadas.':'Horário de atendimento salvo.'};
}
export async function changeAgendaBlock(_state:FormState,data:FormData):Promise<FormState>{
 const ctx=await context(data),doctor=String(data.get('doctor')??''),block=String(data.get('block')??''),start=String(data.get('start')??''),end=String(data.get('end')??'');
 if(!ctx||!ctx.permissions.can_write||!uuid.test(doctor)||(block&&(!uuid.test(block)||!version(data)||data.get('confirm')!=='on'))||(!block&&(!localTime.test(start)||!localTime.test(end))))return {error:'Confira o médico e o intervalo do bloqueio.'};
 const result=await ctx.client.rpc('change_agenda_block',{clinic_id:ctx.clinic.id,doctor_id:doctor,block_id:block||null,start_local:block?null:start,end_local:block?null:end,expected_version:block?version(data):null,own_only:ctx.own,operation_id:ctx.operation});
 const failure=mutationResult(result);if(failure)return failure;refresh();return {message:block?'Bloqueio retirado.':'Horário bloqueado.'};
}
export async function setMyDuration(_state:FormState,data:FormData):Promise<FormState>{
 const ctx=await context(data),duration=Number(data.get('duration'));
 if(!ctx||!ctx.permissions.doctor_membership||![15,30,45,60].includes(duration))return {error:'Selecione uma duração válida para seu perfil médico.'};
 const result=await ctx.client.rpc('set_my_consultation_duration',{clinic_id:ctx.clinic.id,duration_minutes:duration,operation_id:ctx.operation});
 const failure=mutationResult(result);if(failure)return failure;refresh();return {message:'Duração padrão salva. Consultas existentes mantêm sua duração.'};
}
