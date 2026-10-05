'use client';
import {useActionState,useState} from 'react';
import {saveAppointment} from '@/app/agenda/actions';
import {searchPatients,type PatientSearchState} from '@/app/pacientes/actions';
import {initial} from '@/components/form';
import type {AgendaDoctor,Appointment} from '@/lib/agenda-shared';
export function AppointmentForm({clinicId,ownOnly,ownDoctor,doctors,operation,start,appointment,replacements=[]}:{clinicId:string;ownOnly:boolean;ownDoctor:string|null;doctors:AgendaDoctor[];operation:string;start:string;appointment?:Appointment;replacements?:Appointment[]}){
 const [state,action,pending]=useActionState(saveAppointment,initial);
 const searchInitial:PatientSearchState={records:[],has_more:false,page:0,query:''};
 const [search,searchAction,searchPending]=useActionState(searchPatients,searchInitial);
 const [patient,setPatient]=useState(appointment?.patient??'');
 const [doctor,setDoctor]=useState(appointment?.doctor??doctors[0]?.id??'');
 const [replace,setReplace]=useState(false),[replacement,setReplacement]=useState('');
 const defaultDuration=doctors.find(d=>d.id===doctor)?.duration??30;
 const selectedReplacement=replacements.find(a=>a.id===replacement&&a.doctor===doctor);
 const hidden=<><input type="hidden" name="clinic" value={clinicId}/><input type="hidden" name="own" value={ownOnly?'on':''}/></>;
 return <>
 {!appointment&&<form action={searchAction} className="form agenda-patient-picker">{hidden}<input type="hidden" name="page" value="0"/>
 <label htmlFor="agenda-patient-query">Pesquisar paciente por nome ou contato</label><input id="agenda-patient-query" name="query" minLength={3} maxLength={120} required autoComplete="off"/>
 <button className="secondary" disabled={searchPending}>{searchPending?'Pesquisando…':'Pesquisar paciente'}</button>
 {search.error&&<p className="notice error" role="alert">{search.error}</p>}
 {search.records.length?<><label htmlFor="agenda-patient">Paciente</label><select id="agenda-patient" value={patient} onChange={e=>setPatient(e.target.value)}><option value="">Selecione o paciente</option>{search.records.map(p=><option value={p.id} key={p.id}>{p.display_name} · {p.birth_date.split('-').reverse().join('/')}</option>)}</select>{search.has_more&&<p className="field-help">Refine a pesquisa para localizar o paciente entre os primeiros 25 resultados.</p>}</>:<p className="field-help">Pesquise e selecione um paciente do seu acesso. Cadastre primeiro quem ainda não possui cadastro.</p>}
 </form>}
 <form action={action} className="form">{hidden}<input type="hidden" name="operation" value={operation}/><input type="hidden" name="patient" value={patient}/>
 {appointment&&<><input type="hidden" name="appointment" value={appointment.id}/><input type="hidden" name="version" value={appointment.version}/><p>Paciente: <strong>{appointment.patient_name}</strong></p></>}
 <label htmlFor="appointment-doctor">Médico da consulta</label><select id="appointment-doctor" value={doctor} disabled={pending||!!appointment||ownOnly} onChange={e=>{setDoctor(e.target.value);setReplacement('');}}>{doctors.map(d=><option value={d.id} key={d.id}>{d.name}</option>)}</select><input type="hidden" name="doctor" value={doctor}/>
 <label htmlFor="appointment-start">Data e horário da consulta</label><input key={start} id="appointment-start" name="start" type="datetime-local" defaultValue={start} required disabled={pending}/>
 <label htmlFor="appointment-duration">Duração da consulta</label><select key={doctor+':'+defaultDuration} id="appointment-duration" name={doctor===ownDoctor?'duration':undefined} defaultValue={appointment?.duration??defaultDuration} disabled={pending||doctor!==ownDoctor}>{[15,30,45,60].map(n=><option value={n} key={n}>{n} minutos</option>)}</select>
 {doctor!==ownDoctor&&<><input type="hidden" name="duration" value={appointment?.duration??defaultDuration}/><p className="field-help">{appointment?'A duração registrada nesta consulta será mantida.':'A duração padrão do médico será utilizada.'} O próprio médico pode escolher outra duração ao agendar.</p></>}
 {!appointment&&<><label className="checkbox-label"><input type="checkbox" name="replace" checked={replace} onChange={e=>setReplace(e.target.checked)} disabled={pending}/>Substituir consulta existente</label>{replace&&<><p className="notice">Ao salvar, a consulta selecionada será cancelada e seu histórico será preservado. O novo horário precisa coincidir com ela e estar livre de outros conflitos.</p><label htmlFor="replacement">Consulta a substituir</label><select id="replacement" name="replacement" required value={replacement} onChange={e=>setReplacement(e.target.value)} disabled={pending}><option value="">Selecione uma consulta do dia</option>{replacements.filter(a=>a.doctor===doctor&&['agendada','confirmada'].includes(a.status)).map(a=><option key={a.id} value={a.id}>{a.start_local.slice(11)} · {a.patient_name}</option>)}</select><input type="hidden" name="replacement_version" value={selectedReplacement?.version??''}/></>}</>}
 {state.error&&<p role="alert" className="notice error">{state.error}</p>}
 <button className="primary" disabled={pending||!patient||!doctor}>{pending?'Salvando…':appointment?'Salvar reagendamento':'Agendar consulta'}</button>
 </form></>;
}
