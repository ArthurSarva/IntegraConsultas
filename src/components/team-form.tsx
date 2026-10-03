'use client';
import {useActionState,useState} from 'react';import {provisionTeamMember} from '@/app/equipe/actions';import {initial} from '@/components/form';
export function TeamForm({clinicId,operation}:{clinicId:string;operation:string}){
 const [state,action,pending]=useActionState(provisionTeamMember,initial);const [role,setRole]=useState('doctor');const [copied,setCopied]=useState<string|null>(null);
 return <div><form action={action} className="form">
 <input type="hidden" name="clinic" value={clinicId}/><input type="hidden" name="operation" value={operation}/>
 <label htmlFor="team-name">Nome da pessoa</label><input id="team-name" name="name" required maxLength={120} autoComplete="name"/>
 <label htmlFor="team-email">Email da pessoa</label><input id="team-email" name="email" type="email" required maxLength={254} autoComplete="email"/>
 <label htmlFor="team-role">Função</label><select id="team-role" name="role" value={role} onChange={e=>setRole(e.target.value)} disabled={pending}><option value="doctor">Médico</option><option value="reception">Recepção</option></select>
 {role==='doctor'&&<><label htmlFor="team-duration">Duração padrão da consulta</label><select id="team-duration" name="duration" defaultValue="30" disabled={pending}>{[15,30,45,60].map(n=><option key={n} value={n}>{n} minutos</option>)}</select>
 <label className="checkbox-label"><input name="reception" type="checkbox" disabled={pending}/>Também exerce a função de recepção</label><p className="field-help">A função de recepção do médico permite gerenciar somente a própria agenda.</p></>}
 {role==='reception'&&<p className="field-help">A recepção terá acesso aos agendamentos e pacientes desta clínica.</p>}
 {state.error&&<p className="notice error" role="alert">{state.error}</p>}{state.message&&<p className="notice" role="status">{state.message}</p>}
 <button className="primary" disabled={pending}>{pending?'Cadastrando…':'Cadastrar pessoa'}</button></form>
 {state.inviteUrl&&<section className="invite-box"><h3>Convite pessoal</h3><p>Entregue este link somente à pessoa cadastrada. Ela define a própria senha. O link pode ser usado uma vez.</p>
 <label htmlFor="team-invite">Link do convite</label><input id="team-invite" readOnly value={state.inviteUrl} autoComplete="off"/>
 <button className="secondary" onClick={async()=>{try{await navigator.clipboard.writeText(state.inviteUrl!);setCopied(state.inviteUrl!);}catch{setCopied(null);}}}>{copied===state.inviteUrl?'Link copiado':'Copiar convite'}</button>
 <p className="footnote">Nenhum email foi enviado. Repetir o cadastro de uma conta pendente gera outro convite e invalida o link anterior.</p></section>}
 </div>;
}
