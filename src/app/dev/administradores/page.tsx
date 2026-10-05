import {DestructiveForm} from '@/components/destructive-form';
import {removeClinicMember} from '@/app/remocoes/actions';
import {randomUUID} from 'node:crypto';import Link from 'next/link';
import {devWorkspace} from '@/lib/dev';import {AdministratorForm} from '@/components/administrator-form';import {WorkspaceHeader} from '@/components/workspace-header';
import {CancelInvitationForm} from '@/components/cancel-invitation-form';
type Admin={id:string;display_name:string;email:string;active:boolean;confirmed:boolean;cancelled:boolean;invalidation_pending:boolean};
export default async function Administrators(){
 const {client,clinic}=await devWorkspace();const {data,error}=await client.rpc('list_administrators');if(error)throw new Error('Unable to list administrators');
 const admins=(data??[]) as Admin[];
 const removable=await client.rpc('list_removable_members',{clinic_id:clinic.id,member_kind:'administrator'});if(removable.error)throw new Error('Unable to verify removable administrators');
 const versions=new Map<string,number>((removable.data??[]).map((r:{user_id:string;access_version:number})=>[r.user_id,r.access_version]));
 return <div className="workspace"><WorkspaceHeader clinic={clinic.name}/><main id="conteudo"><p className="eyebrow">ADMINISTRAÇÃO DA CLÍNICA</p><h1>Administradores</h1><p className="muted">Cadastre ou vincule um administrador somente à {clinic.name}.</p>
 <div className="admin-grid"><section className="module-card"><h2>Novo administrador</h2><p className="muted">A pessoa define a própria senha pelo convite. Contas já confirmadas mantêm sua senha.</p><AdministratorForm clinicId={clinic.id} operation={randomUUID()}/></section>
 <section className="module-card"><h2>Administradores vinculados</h2>{admins.length?<ul className="admin-list">{admins.map(a=><li key={a.id}><strong>{a.display_name}</strong><span>{a.email}</span><div className="invitation-status"><small>{a.cancelled?(a.invalidation_pending?'Acesso cancelado; invalidação do link pendente':'Convite cancelado'):!a.active?'Acesso inativo':a.confirmed?'Conta confirmada':'Aguardando aceite do convite'}</small>{((a.active&&!a.confirmed&&!a.cancelled)||a.invalidation_pending)&&<CancelInvitationForm clinicId={clinic.id} userId={a.id} operation={randomUUID()} retry={a.cancelled}/>}</div>{versions.has(a.id)&&<DestructiveForm key={a.id+':'+versions.get(a.id)} action={removeClinicMember} label="Remover da clínica" description={'Remover todas as funções de '+a.display_name+' na '+clinic.name+'? A conta, o histórico e os vínculos com outras clínicas serão mantidos.'} fields={{clinic:clinic.id,target:a.id,kind:'administrator',version:String(versions.get(a.id)),operation:randomUUID()}}/>}</li>)}</ul>:<p className="muted">Nenhum administrador vinculado.</p>}</section></div>
 <Link href="/inicio" className="text-link">Voltar ao início</Link></main></div>;
}
