import Link from 'next/link';
import {workspace} from '@/lib/identity';
import {WorkspaceHeader} from '@/components/workspace-header';
import {clinicToday} from '@/lib/patients';
import {statuses,type Appointment} from '@/lib/agenda-shared';

export default async function Home(){
 const {client,profile,clinic}=await workspace();
 const roles=clinic.roles.map(r=>r.role);
 const admin=roles.includes('administrator'),doctor=roles.includes('doctor'),reception=roles.includes('reception');
 const ownOnly=doctor&&!admin&&!profile.is_dev;
 const canClinic=admin||profile.is_dev||(reception&&!doctor);
 const agendaPath=ownOnly?'/minha-agenda':'/agenda';
 const patientPath=ownOnly?'/meus-pacientes':'/pacientes';
 const automationPath=ownOnly?'/minhas-automacoes':'/automacoes';
 const today=clinicToday(clinic.timezone);
 let appointments:Appointment[]=[];
 let agendaAvailable=false;
 if(canClinic||doctor){
  const permissions=await client.rpc('agenda_permissions',{clinic_id:clinic.id});
  if(!permissions.error&&permissions.data){
   const result=await client.rpc('list_agenda',{clinic_id:clinic.id,day:today,doctor_id:ownOnly?permissions.data.doctor_membership:null,own_only:ownOnly,page_number:0});
   if(!result.error&&result.data){appointments=result.data.records as Appointment[];agendaAvailable=true;}
  }
 }
 const confirmed=appointments.filter(a=>a.status==='confirmada').length;
 const pending=appointments.filter(a=>a.status==='agendada').length;
 const upcoming=appointments.filter(a=>['agendada','confirmada'].includes(a.status)).sort((a,b)=>a.start_local.localeCompare(b.start_local)).slice(0,6);
 return <div className="workspace"><WorkspaceHeader clinic={clinic.name}/>
 <main id="conteudo">
  <div className="dashboard-heading"><div><p className="eyebrow">VISÃO GERAL · {clinic.name}</p><h1>Olá, {profile.display_name}.</h1><p className="muted">Acompanhe os atendimentos e as tarefas da sua clínica.</p></div><div className="dashboard-quick-actions"><Link className="secondary link-button" href={patientPath}>Consultar pacientes</Link><Link className="primary link-button" href={agendaPath}>Abrir agenda</Link></div></div>
  {agendaAvailable?<><section className="dashboard-metrics" aria-label="Resumo das consultas do dia">
   <div className="dashboard-metric"><span>Consultas exibidas hoje</span><strong>{appointments.length}</strong><small>Registros desta página da agenda</small></div>
   <div className="dashboard-metric"><span>Confirmadas</span><strong>{confirmed}</strong><small>Entre os registros exibidos</small></div>
   <div className="dashboard-metric"><span>Aguardando confirmação</span><strong>{pending}</strong><small>Entre os registros exibidos</small></div>
  </section>
  <section className="module-card dashboard-appointments"><div className="section-heading"><div><h2>Consultas do dia</h2><p className="field-help">{today.split('-').reverse().join('/')} · {ownOnly?'Minha agenda':'Agenda da clínica'}</p></div><Link href={agendaPath+'?data='+today} className="secondary link-button">Ver agenda completa</Link></div>
   {upcoming.length?<ul className="dashboard-appointment-list">{upcoming.map(a=><li key={a.id}><div><strong>{a.start_local.slice(11,16)}</strong><span>{a.patient_name}</span><small>{a.doctor_name}</small></div><span className={'appointment-status '+a.status}>{statuses[a.status]??a.status}</span><Link className="secondary link-button" href={agendaPath+'/'+a.id}>Detalhes</Link></li>)}</ul>:<p className="muted">Nenhuma consulta ativa nos registros exibidos hoje.</p>}
   <p className="field-help">Resumo da primeira página da agenda. Para consultar todos os registros, abra a agenda completa.</p>
  </section></>:<section className="notice" role="status">O resumo da agenda não está disponível neste acesso. Utilize os módulos autorizados abaixo.</section>}
  <section className="dashboard-shortcuts"><h2>Acesso rápido</h2><div className="dashboard-shortcut-grid">
   <Link href={agendaPath} className="dashboard-shortcut"><strong>{ownOnly?'Minha agenda':'Agenda'}</strong><span>Consultas, horários e bloqueios</span></Link>
   <Link href={patientPath} className="dashboard-shortcut"><strong>{ownOnly?'Meus pacientes':'Pacientes'}</strong><span>Pesquisar e consultar cadastros</span></Link>
   <Link href={automationPath} className="dashboard-shortcut"><strong>Automações</strong><span>Verificar tarefas e pendências</span></Link>
   {(admin||profile.is_dev)&&<Link href="/equipe" className="dashboard-shortcut"><strong>Equipe</strong><span>Profissionais e convites</span></Link>}
   {doctor&&<Link href="/integracoes/google" className="dashboard-shortcut"><strong>Google Agenda</strong><span>Conexão individual</span></Link>}
   {(admin||profile.is_dev)&&<Link href="/integracoes/whatsapp" className="dashboard-shortcut"><strong>WhatsApp</strong><span>Configuração da clínica</span></Link>}
   {profile.is_dev&&<Link href="/dev/administradores" className="dashboard-shortcut"><strong>Administradores</strong><span>Gerenciar administradores</span></Link>}
  </div></section>
  <p className="footnote">A sincronização Google depende da configuração individual. O envio de mensagens por WhatsApp permanece desativado.</p>
 </main></div>;
}
