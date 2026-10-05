'use client';
import Link from 'next/link';
import {useActionState,useState} from 'react';
import {savePatient,type PatientSaveState} from '@/app/pacientes/actions';
import type {Patient} from '@/lib/patients';
export function PatientForm({clinicId,operation,today,patient,ownOnly}:{clinicId:string;operation:string;today:string;patient?:Patient;ownOnly:boolean}){
 const [state,action,pending]=useActionState<PatientSaveState,FormData>(savePatient,{});
 const [revision,setRevision]=useState(0);
 const values=state.values??{name:patient?.display_name??'',birth:patient?.birth_date??'',phone:patient?.phone??'',email:patient?.email??'',cpf:patient?.cpf??''};
 const warning=state.duplicates&&state.revision===revision;
 const path=ownOnly?'/meus-pacientes':'/pacientes';
 return <form key={state.attempt??operation} action={action} className="form patient-form">
  <input type="hidden" name="clinic" value={clinicId}/><input type="hidden" name="operation" value={operation}/><input type="hidden" name="patient" value={patient?.id??''}/><input type="hidden" name="version" value={patient?.version??''}/><input type="hidden" name="own" value={ownOnly?'on':''}/><input type="hidden" name="revision" value={revision}/>
  <fieldset disabled={pending||state.conflict} onChange={()=>setRevision(n=>n+1)}>
   <label htmlFor="patient-name">Nome completo</label><input id="patient-name" name="name" required maxLength={120} defaultValue={values.name} autoComplete="off"/>
   <label htmlFor="patient-birth">Data de nascimento</label><input id="patient-birth" name="birth" type="date" required min="0001-01-01" max={today} defaultValue={values.birth}/>
   <label htmlFor="patient-phone">Telefone / WhatsApp</label><input id="patient-phone" name="phone" type="tel" required maxLength={40} defaultValue={values.phone} placeholder="(11) 99999-9999" autoComplete="off"/><p className="field-help">Informe DDD. Para números internacionais, use + e o código do país. Nenhuma mensagem é enviada nesta etapa.</p>
   <label htmlFor="patient-email">Email (opcional)</label><input id="patient-email" name="email" type="email" maxLength={254} defaultValue={values.email} autoComplete="off"/>
   <label htmlFor="patient-cpf">CPF (opcional)</label><input id="patient-cpf" name="cpf" inputMode="numeric" maxLength={20} defaultValue={values.cpf} autoComplete="off"/>
  </fieldset>
  {warning&&<section className="notice" aria-label="Possíveis cadastros duplicados"><strong>Encontramos possíveis cadastros duplicados.</strong><ul>{state.duplicates!.map(p=><li key={p.id}><Link href={path+'/'+p.id}>{p.display_name}</Link><span> · {p.birth_date.split('-').reverse().join('/')} · {p.phone}</span></li>)}</ul><label className="checkbox-label"><input key={revision} name="duplicate" type="checkbox" disabled={pending}/>Conferi os cadastros e quero salvar mesmo assim</label></section>}
  {state.error&&<p className="notice error" role="alert">{state.error}</p>}
  <button className="primary" disabled={pending||state.conflict}>{pending?'Salvando…':patient?'Salvar alterações':'Cadastrar paciente'}</button>
  {state.conflict&&<a href={path+'/'+patient!.id} className="text-link">Atualizar cadastro</a>}
 </form>;
}
