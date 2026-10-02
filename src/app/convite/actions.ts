'use server';
import {redirect} from 'next/navigation';import {createClient} from '@/lib/supabase/server';import type {FormState} from '@/components/form';
export async function acceptInvite(_state:FormState,data:FormData):Promise<FormState>{
 const token=String(data.get('token')??'');
 if(token.length<32||token.length>512||!/^[A-Za-z0-9_-]+$/.test(token))return {error:'O convite é inválido ou expirou. Solicite um novo link ao responsável.'};
 const client=await createClient();const result=await client.auth.verifyOtp({token_hash:token,type:'invite'});
 if(result.error)return {error:'O convite é inválido ou expirou. Solicite um novo link ao responsável.'};
 redirect('/definir-senha');
}

