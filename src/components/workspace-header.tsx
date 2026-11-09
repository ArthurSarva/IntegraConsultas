import Link from 'next/link';
import {Brand} from '@/components/shell';
import {logout} from '@/app/actions';
import {workspace} from '@/lib/identity';

export async function WorkspaceHeader({clinic}:{clinic:string}) {
 const {profile,clinic:active}=await workspace();
 const roles=active.roles.map(item=>item.role);
 const admin=roles.includes('administrator');
 const doctor=roles.includes('doctor');
 const reception=roles.includes('reception');
 const canClinic=admin||reception||profile.is_dev;
 const ownOnly=doctor&&!admin&&!profile.is_dev;
 const items=[
  {href:'/inicio',label:'Visão geral',icon:'⌂'},
  ...(canClinic?[{href:'/agenda',label:'Agenda',icon:'▦'},{href:'/pacientes',label:'Pacientes',icon:'♙'}]:[]),
  ...(doctor?[{href:'/minha-agenda',label:'Minha agenda',icon:'▤'},{href:'/meus-pacientes',label:'Meus pacientes',icon:'♧'}]:[]),
  ...(admin||profile.is_dev?[{href:'/equipe',label:'Equipe',icon:'♧'}]:[]),
  {href:ownOnly?'/minhas-automacoes':'/automacoes',label:'Automações',icon:'◷'},
 ];
 const settings=[
  ...(doctor?[{href:'/integracoes/google',label:'Google Agenda'}]:[]),
  ...(admin||profile.is_dev?[{href:'/integracoes/whatsapp',label:'WhatsApp'}]:[]),
 ];
 return <div className="workspace-chrome">
  <aside className="workspace-sidebar" aria-label="Navegação principal">
   <div className="sidebar-brand"><Brand/></div>
   <nav className="sidebar-links" aria-label="Módulos">
    {items.map(item=><Link key={item.href} href={item.href} className="sidebar-link"><span aria-hidden="true" className="sidebar-icon">{item.icon}</span>{item.label}</Link>)}
   </nav>
   {settings.length>0&&<div className="sidebar-settings"><span className="sidebar-caption">INTEGRAÇÕES</span>{settings.map(item=><Link className="sidebar-link" key={item.href} href={item.href}>{item.label}</Link>)}</div>}
  </aside>
  <header className="workspace-topbar">
   <div className="topbar-identity"><span className="topbar-kicker">CLÍNICA ATIVA</span><strong>{clinic}</strong></div>
   <div className="topbar-actions"><Link href="/clinicas" className="secondary link-button">Trocar clínica</Link><form action={logout}><button className="quiet">Sair</button></form></div>
  </header>
 </div>;
}
