'use client';
import {useActionState,useState} from 'react';
import {configureAdministratorDoctor} from '@/app/equipe/actions';
import {initial} from '@/components/form';
export function AdministratorDoctorForm({clinicId,operation,isDoctor,duration}:{clinicId:string;operation:string;isDoctor:boolean;duration:number}){
 const [state,action,pending]=useActionState(configureAdministratorDoctor,initial);
 const [checked,setChecked]=useState(isDoctor);
 return <form action={action} className="form">
  <input type="hidden" name="clinic" value={clinicId}/><input type="hidden" name="operation" value={operation}/>
  <label className="checkbox-label"><input key={isDoctor?'active':'inactive'} name="doctor" type="checkbox" checked={isDoctor||checked} disabled={pending||isDoctor} onChange={e=>setChecked(e.target.checked)}/>Também sou médico</label>
  {isDoctor&&<input type="hidden" name="doctor" value="on"/>}
  <p className="field-help">Você mantém a administração da clínica e passa a ter também o perfil de médico, com sua própria agenda e pacientes. Usa a mesma conta e senha.</p>
  {(isDoctor||checked)&&<><label htmlFor="administrator-duration">Minha duração padrão de consulta</label><select key={duration} id="administrator-duration" name="duration" defaultValue={duration} disabled={pending}>{[15,30,45,60].map(n=><option key={n} value={n}>{n} minutos</option>)}</select></>}
  {state.error&&<p className="notice error" role="alert">{state.error}</p>}{state.message&&<p className="notice" role="status">{state.message}</p>}
  <button className="primary" disabled={pending||(!isDoctor&&!checked)}>{pending?'Salvando…':isDoctor?'Salvar minha duração':'Ativar meu perfil de médico'}</button>
  {isDoctor&&<p className="footnote">Seu perfil de médico está ativo nesta clínica.</p>}
 </form>;
}
