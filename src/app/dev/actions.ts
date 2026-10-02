'use server';
import {redirect} from 'next/navigation';
import {revalidatePath} from 'next/cache';
import {dev,devWorkspace} from '@/lib/dev';
import {appOrigin} from '@/lib/config';
import type {FormState} from '@/components/form';
export async function createClinic(_state:FormState,data:FormData):Promise<FormState>{
 const {client}=await dev();
 const name=String(data.get('name')??'').trim(),timezone=String(data.get('timezone')??'');
 const operation=String(data.get('operation')??'');
 if(name.length<1||name.length>160)return {error:'Informe um nome de até 160 caracteres.'};
 const result=await client.rpc('create_clinic',{clinic_name:name,clinic_timezone:timezone,operation_id:operation});
 if(result.error)return {error:'Não foi possível cadastrar a clínica. Confira os dados e tente novamente.'};
 revalidatePath('/','layout');redirect('/clinicas?criada=sim');
}
export async function provisionAdministrator(_state:FormState,data:FormData):Promise<FormState>{
 const {client,clinic}=await devWorkspace();
 const origin=appOrigin();
 if(String(data.get('clinic')??'')!==clinic.id)return {error:'A clínica ativa mudou. Atualize a página antes de continuar.'};
 const email=String(data.get('email')??'').trim(),name=String(data.get('name')??'').trim();
 if(name.length<1||name.length>120||email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email))return {error:'Confira o nome e o email.'};
 const result=await client.functions.invoke('provision-administrator',{body:{clinic_id:clinic.id,display_name:name,email,operation_id:String(data.get('operation')??'')}});
 if(result.error)return {error:'Não foi possível concluir o cadastro. Confira a conta, sua clínica ativa e tente novamente.'};
 revalidatePath('/dev/administradores');
 const hash=result.data.invite_hash as string|undefined;
 return {message:String(result.data.message),inviteUrl:hash?origin+'/convite#token='+encodeURIComponent(hash):undefined};
}
export async function cancelAdministratorInvitation(_state:FormState,data:FormData):Promise<FormState>{
 const {client,clinic}=await devWorkspace();
 if(String(data.get('clinic')??'')!==clinic.id)return {error:'A clínica ativa mudou. Atualize a página antes de continuar.'};
 const result=await client.functions.invoke('provision-administrator',{body:{action:'cancel',clinic_id:clinic.id,user_id:String(data.get('user')??''),operation_id:String(data.get('operation')??'')}});
 revalidatePath('/dev/administradores');
 if(result.error)return {error:'Não foi possível concluir o cancelamento. Atualize a página e tente novamente.'};
 return {message:'Convite cancelado. O link anterior não pode mais ser utilizado.'};
}
