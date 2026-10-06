import Link from 'next/link';
import {agendaWorkspace,uuid,localDisplay} from '@/lib/agenda';
import {WorkspaceHeader} from '@/components/workspace-header';
type Task={id:string;appointment:string;appointment_version:number;doctor_name:string;kind:'google_sync'|'whatsapp_reminder';status:string;reason:string|null;attempts:number;due_local:string;available_local:string;updated_local:string};
const labels:Record<string,string>={pending:'Aguardando processamento',processing:'Em processamento',retry:'Nova tentativa programada',blocked:'Aguardando solução',completed:'Processada',cancelled:'Cancelada',failed:'Falha'};
const reasons:Record<string,string>={google_conflict:"Conflito no Google Agenda; escolha outro horário",integration_not_configured:'Integração ainda não configurada',superseded:'A consulta foi alterada; esta tarefa perdeu a validade',expired:'O prazo da tarefa terminou',access_revoked:'O acesso ou vínculo necessário está inativo',transient_failure:'Falha temporária; uma nova tentativa foi programada',permanent_failure:'Falha que exige análise',lease_expired:'O processamento foi interrompido',result_unknown:'Resultado incerto; exige análise antes de repetir',retry_policy_pending:'A política de repetição de mensagens ainda precisa ser definida',attempts_exhausted:'Limite de tentativas atingido'};
export async function AutomationPage({ownOnly=false,query={}}:{ownOnly?:boolean;query?:{pagina?:string;consulta?:string}}){
 const {client,clinic,path}=await agendaWorkspace(ownOnly);
 const page=Math.min(10000,Math.max(0,Number.isInteger(Number(query.pagina))?Number(query.pagina):0));
 const appointment=query.consulta&&uuid.test(query.consulta)?query.consulta:null;
 const response=await client.rpc('list_automations',{clinic_id:clinic.id,own_only:ownOnly,page_number:page,appointment_id:appointment});
 if(response.error)throw new Error('Unable to list automation tasks');
 const records=response.data.records as Task[],route=ownOnly?'/minhas-automacoes':'/automacoes',suffix=appointment?'&consulta='+appointment:'';
 return <div className="workspace"><WorkspaceHeader clinic={clinic.name}/><main id="conteudo"><p className="eyebrow">{clinic.name}</p><h1>{ownOnly?'Automações da minha agenda':'Automações da clínica'}</h1>
 <p className="muted">Acompanhe o planejamento e as pendências das consultas dentro do seu acesso.</p>
 <p className="notice">Acompanhe aqui o resultado da sincronização Google. O processamento precisa ser ativado pelo responsável do sistema. WhatsApp ainda não envia mensagens.</p>
 <p className="field-help">Horários no fuso {clinic.timezone}. {response.data.worker?.last_run_local?'Última verificação automática: '+localDisplay(response.data.worker.last_run_local)+'.':'A primeira verificação automática ainda não foi registrada.'}</p>
 {appointment&&<p><Link href={route} className="text-link">Ver tarefas de todas as consultas do meu acesso</Link></p>}
 <form method="get" className="agenda-toolbar">{appointment&&<input type="hidden" name="consulta" value={appointment}/>}<button className="secondary">Atualizar tarefas</button></form>
 <section className="module-card"><h2>Tarefas das consultas</h2>{records.length?<ul className="appointment-list automation-list">{records.map(task=><li key={task.id} data-task-id={task.id}><div>
 <strong>{task.kind==='google_sync'?'Google Agenda':'Lembrete por WhatsApp'}</strong><span>{task.doctor_name} · consulta na versão {task.appointment_version}</span>
 <span className="badge">{labels[task.status]??'Situação indisponível'}</span>{task.reason&&<span>{reasons[task.reason]??'Pendência que exige análise'}</span>}
 <span>Previsto para {localDisplay(task.due_local)}</span><span>Tentativas: {task.attempts}</span>
 {task.status==='retry'&&<span>Próxima tentativa: {localDisplay(task.available_local)}</span>}
 <span className="field-help">Atualizado em {localDisplay(task.updated_local)}</span></div>
 <Link href={path+'/'+task.appointment} className="secondary link-button">Ver consulta</Link></li>)}</ul>:<p className="muted">Nenhuma tarefa de automação neste acesso.</p>}
 <div className="pagination">{page>0?<Link href={route+'?pagina='+(page-1)+suffix} className="secondary link-button">Anterior</Link>:<span/>}<span>Página {page+1}</span>{response.data.has_more&&<Link href={route+'?pagina='+(page+1)+suffix} className="secondary link-button">Próxima</Link>}</div></section>
 <p className="footnote">Cada alteração da consulta invalida tarefas antigas. Uma tarefa processada não comprova entrega de mensagem. Lembretes elegíveis são planejados para as 8h da véspera; consultas marcadas com menos de 24h ou após esse horário não recebem programação tardia.</p>
 <Link href={path} className="text-link">Voltar à agenda</Link></main></div>;
}
