import {randomUUID} from 'node:crypto';import Link from 'next/link';import {teamWorkspace} from '@/lib/team';import {TeamForm} from '@/components/team-form';import {WorkspaceHeader} from '@/components/workspace-header';
import {AdministratorDoctorForm} from '@/components/administrator-doctor-form';
type Person={id:string;display_name:string;email:string;active:boolean;confirmed:boolean;roles:{role:'doctor'|'reception';scope:'own'|'clinic'}[];duration_minutes:number|null};
export default async function Team(){
 const {client,clinic,profile}=await teamWorkspace();const result=await client.rpc('list_team');if(result.error)throw new Error('Unable to list clinic team');
 const people=(result.data??[]) as Person[];
 return <div className="workspace"><WorkspaceHeader clinic={clinic.name}/><main id="conteudo"><p className="eyebrow">ADMINISTRAÇÃO DA CLÍNICA</p><h1>Equipe da clínica</h1><p className="muted">Cadastre médicos e recepção somente na {clinic.name}.</p>
 {!profile.is_dev&&clinic.roles.some(r=>r.role==='administrator')&&<section className="module-card self-profile"><h2>Meu perfil na clínica</h2><AdministratorDoctorForm key={clinic.id} clinicId={clinic.id} operation={randomUUID()} isDoctor={clinic.roles.some(r=>r.role==='doctor')} duration={people.find(p=>p.id===profile.id)?.duration_minutes??30}/></section>}
 <div className="admin-grid"><section className="module-card"><h2>Nova pessoa</h2><p className="muted">Cada pessoa recebe seu próprio acesso. Contas já confirmadas mantêm sua senha e os vínculos existentes.</p><TeamForm clinicId={clinic.id} operation={randomUUID()}/></section>
 <section className="module-card"><h2>Médicos e recepção</h2>{people.length?<ul className="admin-list">{people.map(p=>{const doctor=p.roles.some(r=>r.role==='doctor'),reception=p.roles.some(r=>r.role==='reception');return <li key={p.id}><strong>{p.display_name}</strong><span>{p.email}</span><span>{doctor&&reception?'Médico e recepção · própria agenda':doctor?'Médico · própria agenda':'Recepção · agenda da clínica'}</span>{doctor&&<span>Duração padrão: {p.duration_minutes??30} minutos</span>}<small>{!p.active?'Acesso inativo':p.confirmed?'Conta confirmada':'Aguardando aceite do convite'}</small></li>;})}</ul>:<p className="muted">Nenhuma pessoa cadastrada na equipe.</p>}</section></div>
 <Link href="/inicio" className="text-link">Voltar ao início</Link></main></div>;
}
