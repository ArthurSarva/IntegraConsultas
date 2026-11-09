'use client';
import Link from 'next/link';
import {useActionState} from 'react';
import {searchPatients,type PatientSearchState} from '@/app/pacientes/actions';
export function PatientList({clinicId,ownOnly,initial}:{clinicId:string;ownOnly:boolean;initial:PatientSearchState}){
 const [state,action,pending]=useActionState(searchPatients,initial),path=ownOnly?'/meus-pacientes':'/pacientes';
 const hidden=<><input type="hidden" name="clinic" value={clinicId}/><input type="hidden" name="own" value={ownOnly?'on':''}/></>;
 return <section className="module-card patient-search"><div className="section-heading"><div><h2>Pacientes cadastrados</h2><p className="field-help">Pesquise e abra um cadastro para consultar dados e histórico.</p></div></div>
  <form action={action} className="form patient-search-form">{hidden}<input type="hidden" name="page" value="0"/><label htmlFor="patient-query">Nome, telefone, email ou CPF</label><input key={state.query} id="patient-query" name="query" defaultValue={state.query} maxLength={120} autoComplete="off"/><button className="primary" disabled={pending}>{pending?'Pesquisando…':'Pesquisar'}</button><p className="field-help">Use pelo menos três caracteres ou deixe vazio para listar. A pesquisa não fica no endereço da página.</p></form>
  {state.error&&<p className="notice error" role="alert">{state.error}</p>}
  {state.records.length?<ul className="patient-list" aria-label="Resultados da pesquisa">{state.records.map(p=><li key={p.id}><div><Link href={path+'/'+p.id}><strong>{p.display_name}</strong></Link><span>Nascimento: {p.birth_date.split('-').reverse().join('/')}</span><span>{p.phone}</span>{p.cpf_suffix&&<small>CPF terminado em {p.cpf_suffix}</small>}</div><Link href={path+'/'+p.id} className="secondary link-button">Ver cadastro</Link></li>)}</ul>:<p className="muted" role="status">Nenhum paciente encontrado neste acesso.</p>}
  <form action={action} className="pagination">{hidden}<input type="hidden" name="query" value={state.query}/><button className="secondary" name="page" value={state.page-1} disabled={pending||state.page===0}>Anterior</button><span>Página {state.page+1}</span><button className="secondary" name="page" value={state.page+1} disabled={pending||!state.has_more}>Próxima</button></form>
 </section>;
}
