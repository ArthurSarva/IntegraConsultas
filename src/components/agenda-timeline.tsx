import Link from 'next/link';
import {statuses,type Appointment,type AgendaBlock} from '@/lib/agenda-shared';

export function AgendaTimeline({records,blocks,path}:{records:Appointment[];blocks:AgendaBlock[];path:string}){
 const sorted=[...records].sort((a,b)=>a.start_local.localeCompare(b.start_local));
 const hours=Array.from({length:24},(_,i)=>i);
 return <div className="agenda-timeline" aria-label="Consultas por horário">
  {hours.map(hour=>{
   const appointments=sorted.filter(a=>Number(a.start_local.slice(11,13))===hour);
   const occupied=blocks.filter(b=>b.start_local.slice(0,10)===b.end_local.slice(0,10)&&Number(b.start_local.slice(11,13))<=hour&&Number(b.end_local.slice(11,13))>=hour);
   return <div className="agenda-time-row" key={hour}><time className="agenda-time-label">{String(hour).padStart(2,'0')}:00</time><div className="agenda-time-content">
    {appointments.map(a=><Link href={path+'/'+a.id} className={'agenda-event agenda-event-'+a.status} key={a.id}><strong>{a.start_local.slice(11,16)} · {a.patient_name}</strong><span>{a.doctor_name} · {a.duration} min</span><small>{statuses[a.status]??a.status}</small></Link>)}
    {occupied.map(b=><div className="agenda-block-event" key={b.id}>Bloqueio · {b.doctor_name} · {b.start_local.slice(11,16)}–{b.end_local.slice(11,16)}</div>)}
    {!appointments.length&&!occupied.length&&<span className="agenda-empty-slot" aria-label="Sem registros neste horário">—</span>}
   </div></div>;
  })}
  <p className="field-help">Visão por hora dos registros carregados. Consulte a lista para acessar a paginação e os horários fora da faixa exibida.</p>
 </div>;
}
