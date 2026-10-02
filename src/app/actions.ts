'use server';
import {redirect} from 'next/navigation';
import {revalidatePath} from 'next/cache';
import {authenticated,authorized} from '@/lib/identity';
import {createClient} from '@/lib/supabase/server';
import {appOrigin} from '@/lib/config';
import type {FormState} from '@/components/form';
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
  const {client}=await authenticated();
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
