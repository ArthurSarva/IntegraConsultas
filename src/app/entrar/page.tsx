import Link from 'next/link';
import {login} from '@/app/actions';
import {ActionForm} from '@/components/form';
import {AuthShell} from '@/components/shell';
export default async function Login({searchParams}:{searchParams:Promise<{senha?:string}>}) {
 const query=await searchParams;
 return <AuthShell title="Bem-vindo de volta" description="Entre para acessar as clínicas vinculadas à sua conta.">
 {query.senha==='atualizada' && <p className="notice" role="status">Senha atualizada. Entre com sua nova senha.</p>}
 <ActionForm action={login} label="Entrar"><label htmlFor="email">Email</label><input id="email" name="email" type="email" autoComplete="username" required maxLength={254}/><label htmlFor="password">Senha</label><input id="password" name="password" type="password" autoComplete="current-password" required maxLength={128}/></ActionForm>
 <Link className="text-link" href="/recuperar">Esqueci minha senha</Link><p className="footnote">Seu acesso é disponibilizado pela administração.</p></AuthShell>;
}
