'use server';
import {redirect} from 'next/navigation';
import {revalidatePath} from 'next/cache';
import {identity} from '@/lib/identity';
import type {FormState} from '@/components/form';
export async function enroll(_state:FormState,_data:FormData):Promise<FormState>{
 const {client}=await identity();
 const {data:factors,error:factorError}=await client.auth.mfa.listFactors();
 if(factorError)return {error:'Não foi possível verificar seus autenticadores.'};
 if(factors.totp.length)return {error:'Use o autenticador já configurado para confirmar seu acesso.'};
 for(const factor of factors.all.filter(f=>f.factor_type==='totp'&&f.status==='unverified'&&f.friendly_name==='IntegraConsultas')){
   const {error}=await client.auth.mfa.unenroll({factorId:factor.id});
   if(error)return {error:'Não foi possível reiniciar a configuração. Tente novamente.'};
 }
 const {data,error}=await client.auth.mfa.enroll({factorType:'totp',friendlyName:'IntegraConsultas',issuer:'IntegraConsultas'});
 if(error)return {error:'Não foi possível configurar o autenticador. Tente novamente.'};
 return {factorId:data.id,qr:data.totp.qr_code,secret:data.totp.secret};
}
export async function verify(_state:FormState,data:FormData):Promise<FormState>{
 const factorId=String(data.get('factor')??'');
 const code=String(data.get('code')??'').trim();
 if(!/^\d{6}$/.test(code))return {error:'Informe o código de seis dígitos do seu aplicativo.'};
 const {client}=await identity();
 const {error}=await client.auth.mfa.challengeAndVerify({factorId,code});
 if(error)return {error:'Código inválido ou expirado. Confira o aplicativo e tente novamente.'};
 revalidatePath('/','layout');redirect('/clinicas');
}
