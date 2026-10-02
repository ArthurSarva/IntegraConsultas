import Link from 'next/link';
import {recover} from '@/app/actions';
import {ActionForm} from '@/components/form';
import {AuthShell} from '@/components/shell';
export default function Recover(){return <AuthShell title="Recuperar acesso" description="Informe seu email para receber as instruções de recuperação."><ActionForm action={recover} label="Solicitar recuperação"><label htmlFor="email">Email</label><input id="email" name="email" type="email" autoComplete="email" required maxLength={254}/></ActionForm><Link className="text-link" href="/entrar">Voltar para entrar</Link></AuthShell>;}
