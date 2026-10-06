import Link from 'next/link';
import {WorkspaceHeader} from '@/components/workspace-header';
import {googleConfigured,googleWorkspace,readPending,listCalendars,refreshAccess} from '@/lib/google';
import {connectGoogle,selectGoogleCalendar,disconnectGoogle} from './actions';
export default async function GooglePage({searchParams}:{searchParams:Promise<{erro?:string;conectado?:string;desconectado?:string}>}){
 const ctx=await googleWorkspace(),query=await searchParams,configured=googleConfigured();
 const response=await ctx.client.rpc('google_status',{clinic_id:ctx.clinic.id});if(response.error)throw new Error('Unable to verify Google connection');
 const pending=configured?await readPending(ctx):null;
 let calendars:Awaited<ReturnType<typeof listCalendars>>=[],providerError=false;
 if(pending){try{calendars=await listCalendars(await refreshAccess(pending.refresh));}catch{providerError=true;}}
 return <div className="workspace"><WorkspaceHeader clinic={ctx.clinic.name}/><main id="conteudo">
 <p className="eyebrow">Minha agenda · {ctx.clinic.name}</p><h1>Conectar Google Agenda</h1>
 <p className="muted">Escolha a agenda Google que será vinculada ao seu perfil médico nesta clínica.</p>
 {(query.erro||providerError)&&<p className="error" role="alert">Não foi possível concluir a conexão. Confira sua conta, as permissões solicitadas e a clínica ativa. Se o prazo terminou, inicie novamente.</p>}
 {query.conectado&&<p className="notice" role="status">Sua agenda Google foi vinculada à clínica.</p>}
 {query.desconectado&&<p className="notice" role="status">A conexão desta clínica foi removida. Suas consultas foram preservadas.</p>}
 <section className="module-card"><h2>{response.data.connected?'Agenda vinculada':'Autorização individual'}</h2>
 {response.data.connected?<><p><strong>{response.data.calendar_name}</strong></p><p className="muted">Vínculo de sua agenda registrado nesta clínica.</p>
 <form action={disconnectGoogle} className="form patient-form"><input type="hidden" name="clinic" value={ctx.clinic.id}/><label className="checkbox-label"><input type="checkbox" name="confirm" required/> Confirmo desconectar minha agenda desta clínica</label><button className="secondary">Desconectar Google Agenda</button></form></>
 :pending?<><p>Selecione uma agenda de sua propriedade. Agendas compartilhadas por outras pessoas não aparecem nesta etapa.</p>
 {calendars.length?<form action={selectGoogleCalendar} className="form patient-form"><input type="hidden" name="clinic" value={ctx.clinic.id}/><label htmlFor="calendar">Minha agenda Google</label><select id="calendar" name="calendar" required>{calendars.map(item=><option value={item.id} key={item.id}>{item.summary}</option>)}</select><button className="primary">Vincular esta agenda</button></form>:<p className="muted">Nenhuma agenda disponível. Confira a conta escolhida ou tente novamente.</p>}
 <form action={connectGoogle} className="form patient-form"><input type="hidden" name="clinic" value={ctx.clinic.id}/><button className="secondary">Escolher outra conta Google</button></form></>
 :configured?<><p>Você autoriza o acesso diretamente no Google. O sistema solicitará a lista de agendas, a consulta de disponibilidade e a criação, alteração e remoção de eventos em agendas de sua propriedade.</p><form action={connectGoogle} className="form patient-form"><input type="hidden" name="clinic" value={ctx.clinic.id}/><button className="primary">Conectar Google Agenda</button></form></>
 :<p className="notice">A integração Google ainda precisa ser configurada pela administração do sistema.</p>}
 </section><p className="notice">Esta etapa registra a conexão. A sincronização automática das consultas ainda está em preparação; vincular a agenda não envia consultas ao Google.</p>
 <p className="footnote">Ao desconectar, o acesso armazenado para esta clínica é removido. Eventos já existentes no Google são preservados. Para revogar também a autorização no Google, use as configurações de sua Conta Google; isso pode afetar conexões em outras clínicas.</p>
 <Link href="/minha-agenda" className="text-link">Voltar à minha agenda</Link></main></div>;
}
