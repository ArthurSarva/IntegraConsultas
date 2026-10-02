import Link from 'next/link';import {AuthShell} from '@/components/shell';
export default function Invalid(){return <AuthShell title="Link indisponível" description="Este link é inválido, já foi usado ou expirou."><Link className="primary link-button" href="/recuperar">Solicitar novo link</Link><Link className="text-link" href="/entrar">Voltar para entrar</Link></AuthShell>;}
