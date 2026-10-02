import {randomUUID} from 'node:crypto';import Link from 'next/link';
import {devWorkspace} from '@/lib/dev';import {AdministratorForm} from '@/components/administrator-form';import {WorkspaceHeader} from '@/components/workspace-header';
type Admin={id:string;display_name:string;email:string;active:boolean;confirmed:boolean};
export default async function Administrators(){
 const {client,clinic}=await devWorkspace();const {data,error}=await client.rpc('list_administrators');if(error)throw new Error('Unable to list administrators');
 const admins=(data??[]) as Admin[];
 return <div className="workspace"><WorkspaceHeader clinic={clinic.name}/><main id="conteudo"><p className="eyebrow">ADMINISTRAÇÃO DA CLÍNICA</p><h1>Administradores</h1><p className="muted">Cadastre ou vincule um administrador somente à {clinic.name}.</p>
 <div className="admin-grid"><section className="module-card"><h2>Novo administrador</h2><p className="muted">A pessoa define a própria senha pelo convite. Contas já confirmadas mantêm sua senha.</p><AdministratorForm clinicId={clinic.id} operation={randomUUID()}/></section>
 <section className="module-card"><h2>Administradores vinculados</h2>{admins.length?<ul className="admin-list">{admins.map(a=><li key={a.id}><strong>{a.display_name}</strong><span>{a.email}</span><small>{!a.active?'Acesso inativo':a.confirmed?'Conta confirmada':'Aguardando aceite do convite'}</small></li>)}</ul>:<p className="muted">Nenhum administrador vinculado.</p>}</section></div>
 <Link href="/inicio" className="text-link">Voltar ao início</Link></main></div>;
}

