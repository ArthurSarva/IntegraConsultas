import Link from 'next/link';import {workspace} from '@/lib/identity';import {WorkspaceHeader} from '@/components/workspace-header';
export default async function Home(){
 const {profile,clinic}=await workspace();
 const roles=clinic.roles.map(r=>r.role);
 const admin=roles.includes('administrator');const doctor=roles.includes('doctor');const reception=roles.includes('reception');
 const label=profile.is_dev?'Dev':admin&&doctor?'Administrador de clínica e médico':admin?'Administrador de clínica':doctor&&reception?'Médico e recepção':doctor?'Médico':'Recepção';
 return <div className="workspace"><WorkspaceHeader clinic={clinic.name}/>
 <main id="conteudo"><p className="eyebrow">{label}</p><h1>Olá, {profile.display_name}.</h1><p className="muted">Este é seu espaço na {clinic.name}.</p><section className="status-card"><span className="status-dot"/><div><strong>Acesso seguro configurado</strong><p>Sua sessão e as permissões desta clínica foram verificadas.</p></div></section>
 {profile.is_dev&&<section className="status-card"><div><strong>Administradores da clínica</strong><p>Cadastre administradores ou vincule contas existentes à clínica ativa.</p><Link href="/dev/administradores" className="text-link">Gerenciar administradores</Link></div></section>}
 {(profile.is_dev||admin)&&<section className="status-card"><div><strong>Equipe da clínica</strong><p>Cadastre médicos e recepção, com convites individuais.</p><Link href="/equipe" className="text-link">Gerenciar equipe</Link></div></section>}
 <div className="module-grid">{[...(profile.is_dev||admin?[['Gestão da clínica','Equipe, pacientes e organização da clínica.'],['Auditoria','Histórico de acessos e ações desta clínica.']]:[]),...(doctor?[['Minha agenda','Seus horários e suas consultas.'],['Meus pacientes','Pacientes vinculados aos seus atendimentos.']]:!profile.is_dev&&!admin?[['Agenda da clínica','Organização dos horários e das consultas.'],['Pacientes','Cadastro e pesquisa de pacientes.']]:[])].map(([title,description])=><section className="module-card" key={title}><span className="badge">Em preparação</span><h2>{title}</h2><p>{description}</p></section>)}</div>
 <p className="footnote">{doctor&&reception&&!admin&&!profile.is_dev?'Sua função de recepção será limitada à sua própria agenda. ':''}Os módulos operacionais serão disponibilizados nas próximas etapas.</p></main></div>;
}
