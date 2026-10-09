'use server';
import {redirect} from 'next/navigation';
import {revalidatePath} from 'next/cache';
import {authenticated,authorized} from '@/lib/identity';
import {createClient} from '@/lib/supabase/server';
import {appOrigin} from '@/lib/config';
import type {FormState} from '@/components/form';
import {passwordSecurity} from '@/lib/password-security';
const text=(data:FormData,key:string)=>String(data.get(key)??'').trim();
export async function login(_state:FormState,data:FormData):Promise<FormState> {
  const email=text(data,'email'); const password=String(data.get('password')??'');
  if (!email || !password) return {error:'Informe email e senha.'};
  const client=await createClient();
  const {error}=await client.auth.signInWithPassword({email,password});
  if (error) return {error:'Não foi possível entrar. Confira seus dados e tente novamente.'};
  revalidatePath('/','layout'); redirect('/clinicas');
}
export async function logout() {
  const client=await createClient();
  const {error}=await client.auth.signOut({scope:'local'});
  if (error) throw new Error('Unable to end session');
  revalidatePath('/','layout'); redirect('/entrar');
}
export async function recover(_state:FormState,data:FormData):Promise<FormState> {
  const email=text(data,'email');
  if (!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)) return {error:'Informe um email válido.'};
  const client=await createClient();
  await client.auth.resetPasswordForEmail(email,{redirectTo:appOrigin()+'/auth/confirmar'});
  return {message:'Se o endereço puder receber a recuperação, enviaremos as instruções. Confira também a pasta de spam.'};
}
export async function updatePassword(_state:FormState,data:FormData):Promise<FormState> {
  const password=String(data.get('password')??'');
  if (password.length<12 || password.length>128) return {error:'Use uma senha de 12 a 128 caracteres.'};
  if (password!==String(data.get('confirm')??'')) return {error:'As senhas precisam ser iguais.'};
  const {client,user}=await authenticated();
  const security=await passwordSecurity(client,user.id);
  if(security.mode==='recovery')return {error:'Para definir sua senha, solicite e abra um novo link de recuperação.'};
  if(security.mode==='totp'){
    const code=text(data,'code');
    if(!security.factor||!/^\d{6}$/.test(code))return {error:'Confirme o código de seis dígitos do seu aplicativo autenticador.'};
    const verification=await client.auth.mfa.challengeAndVerify({factorId:security.factor.id,code});
    if(verification.error)return {error:'Código inválido ou expirado. Confira o aplicativo e tente novamente.'};
    if((await passwordSecurity(client,user.id)).mode!=='allowed')return {error:'Não foi possível confirmar seu acesso. Tente novamente.'};
  }
  const {error}=await client.auth.updateUser({password});
  if (error) return {error:'Não foi possível definir a senha. O link pode ter expirado ou pode ser necessária uma nova verificação.'};
  const {error:signOutError}=await client.auth.signOut({scope:'global'});
  if (signOutError) return {error:'Senha atualizada. Não foi possível encerrar as sessões; tente sair novamente.'};
  revalidatePath('/','layout'); redirect('/entrar?senha=atualizada');
}
export async function selectClinic(_state:FormState,data:FormData):Promise<FormState> {
  const id=text(data,'clinic');
  if (!/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i.test(id)) return {error:'Selecione uma clínica válida.'};
  const {client}=await authorized();
  const {error}=await client.rpc('select_clinic',{clinic_id:id});
  if (error) return {error:'Não foi possível selecionar esta clínica. Confira seu acesso e tente novamente.'};
  revalidatePath('/','layout'); redirect('/inicio');
}

