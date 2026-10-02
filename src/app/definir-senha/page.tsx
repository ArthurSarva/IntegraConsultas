import {authenticated} from '@/lib/identity';
import {updatePassword} from '@/app/actions';
import {ActionForm} from '@/components/form';
import {AuthShell} from '@/components/shell';
export default async function Password(){await authenticated();return <AuthShell title="Defina sua senha" description="Use uma senha exclusiva, com pelo menos 12 caracteres."><ActionForm action={updatePassword} label="Salvar senha"><label htmlFor="password">Nova senha</label><input id="password" name="password" type="password" autoComplete="new-password" minLength={12} maxLength={128} required/><label htmlFor="confirm">Confirmar senha</label><input id="confirm" name="confirm" type="password" autoComplete="new-password" minLength={12} maxLength={128} required/></ActionForm></AuthShell>;}
