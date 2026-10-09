import {authenticated} from '@/lib/identity';
import Link from 'next/link';
import {passwordSecurity} from '@/lib/password-security';
import {updatePassword} from '@/app/actions';
import {ActionForm} from '@/components/form';
import {AuthShell} from '@/components/shell';
export default async function Password(){
 const {client,user}=await authenticated();const {mode}=await passwordSecurity(client,user.id);
 return <AuthShell title="Defina sua senha" description="Use uma senha exclusiva, com pelo menos 12 caracteres.">
 {mode==='recovery'?<><p className="notice">Para definir sua senha, solicite e abra um novo link de recuperação.</p><Link className="text-link" href="/recuperar">Solicitar recuperação de senha</Link></>:<ActionForm action={updatePassword} label="Salvar senha">
 <label htmlFor="password">Nova senha</label><input id="password" name="password" type="password" autoComplete="new-password" minLength={12} maxLength={128} required/>
 <label htmlFor="confirm">Confirmar senha</label><input id="confirm" name="confirm" type="password" autoComplete="new-password" minLength={12} maxLength={128} required/>
 {mode==='totp'&&<><p className="field-help">Confirme novamente seu acesso com o aplicativo autenticador.</p><label htmlFor="code">Código do autenticador</label><input id="code" name="code" inputMode="numeric" autoComplete="one-time-code" pattern="[0-9]{6}" minLength={6} maxLength={6} required/></>}
 </ActionForm>}</AuthShell>;
}

