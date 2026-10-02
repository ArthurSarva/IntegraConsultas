import Link from 'next/link';import {workspace} from '@/lib/identity';import {logout} from '@/app/actions';import {Brand} from '@/components/shell';
export default async function Home(){
 const {profile,clinic}=await workspace();
 const roles=clinic.roles.map(r=>r.role);
 const admin=roles.includes('administrator');const doctor=roles.includes('doctor');const reception=roles.includes('reception');
 const label=profile.is_dev?'Dev':admin?'Administrador de clínica':doctor&&reception?'Médico e recepção':doctor?'Médico':'Recepção';
 return <div className="workspace"><header><Brand/><div className="clinic-header"><span>CLÍNICA ATIVA</span><strong>{clinic.name}</strong></div><Link href="/clinicas" className="secondary link-button">Trocar clínica</Link><form action={logout}><button className="quiet">Sair</button></form></header>
 <main id="conteudo"><p className="eyebrow">{label}</p><h1>Olá, {profile.display_name}.</h1><p className="muted">Este é seu espaço na {clinic.name}.</p><section className="status-card"><span className="status-dot"/><div><strong>Acesso seguro configurado</strong><p>Sua sessão e as permissões desta clínica foram verificadas.</p></div></section>
 <div className="module-grid">{(profile.is_dev||admin?[['Gestão da clínica','Equipe, pacientes e organização da clínica.'],['Auditoria','Histórico de acessos e ações desta clínica.']]:doctor?[['Minha agenda','Seus horários e suas consultas.'],['Meus pacientes','Pacientes vinculados aos seus atendimentos.']]:[['Agenda da clínica','Organização dos horários e das consultas.'],['Pacientes','Cadastro e pesquisa de pacientes.']]).map(([title,description])=><section className="module-card" key={title}><span className="badge">Em preparação</span><h2>{title}</h2><p>{description}</p></section>)}</div>
 <p className="footnote">{doctor&&reception&&!admin&&!profile.is_dev?'Sua função de recepção será limitada à sua própria agenda. ':''}Os módulos operacionais serão disponibilizados nas próximas etapas.</p></main></div>;
}
