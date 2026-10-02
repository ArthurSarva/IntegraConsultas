import 'server-only';
import {redirect} from 'next/navigation';
import {createClient} from '@/lib/supabase/server';
export type Profile={id:string;display_name:string;is_dev:boolean;requires_mfa:boolean};
export type Workspace={id:string;name:string;timezone:string;roles:{role:'administrator'|'doctor'|'reception';scope:'own'|'clinic'}[]};
export async function authenticated() {
  const client=await createClient();
  const {data,error}=await client.auth.getUser();
  if (error || !data.user) redirect('/entrar');
  return {client,user:data.user};
}
export async function identity() {
  const {client,user}=await authenticated();
  const {data,error}=await client.rpc('session_profile');
  if (error) throw new Error('Unable to verify access');
  if (!data) redirect('/sem-acesso');
  const profile=data as Profile;
  const {data:aal,error:aalError}=await client.auth.mfa.getAuthenticatorAssuranceLevel();
  if (aalError) throw new Error('Unable to verify MFA');
  return {client,user,profile,needsMfa:aal.currentLevel!=='aal2' && (profile.requires_mfa || aal.nextLevel==='aal2')};
}
export async function authorized() {
  const result=await identity();
  if (result.needsMfa) redirect('/seguranca');
  return result;
}
export async function workspace() {
  const result=await authorized();
  const {data,error}=await result.client.rpc('workspace');
  if (error) throw new Error('Unable to verify clinic');
  if (!data) redirect('/clinicas');
  return {...result,clinic:data as Workspace};
}
