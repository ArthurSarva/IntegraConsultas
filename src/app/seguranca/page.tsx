import {redirect} from 'next/navigation';import {identity} from '@/lib/identity';import {logout} from '@/app/actions';import {Mfa} from '@/components/mfa';import {AuthShell} from '@/components/shell';
export default async function Security(){
 const {client,needsMfa}=await identity();if(!needsMfa)redirect('/clinicas');
 const {data,error}=await client.auth.mfa.listFactors();if(error)throw new Error('Unable to load MFA');
 return <AuthShell title="Confirme seu acesso" description="Use seu aplicativo autenticador para proteger sua conta."><Mfa factors={data.totp.map(f=>({id:f.id,friendly_name:f.friendly_name}))}/><form action={logout}><button className="quiet">Sair da conta</button></form><p className="footnote">Se perdeu o autenticador, solicite recuperação à administração.</p></AuthShell>;
}
