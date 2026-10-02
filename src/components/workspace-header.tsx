import Link from 'next/link';import {Brand} from '@/components/shell';import {logout} from '@/app/actions';
export function WorkspaceHeader({clinic}:{clinic:string}){return <header><Brand/><div className="clinic-header"><span>CLÍNICA ATIVA</span><strong>{clinic}</strong></div><Link href="/clinicas" className="secondary link-button">Trocar clínica</Link><form action={logout}><button className="quiet">Sair</button></form></header>;}

