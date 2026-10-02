'use client';
import {useActionState,useState} from 'react';import {provisionAdministrator} from '@/app/dev/actions';import {initial} from '@/components/form';
export function AdministratorForm({clinicId,operation}:{clinicId:string;operation:string}){
 const [state,action,pending]=useActionState(provisionAdministrator,initial);const [copied,setCopied]=useState(false);
 return <div><form action={action} className="form"><input type="hidden" name="clinic" value={clinicId}/><input type="hidden" name="operation" value={operation}/>
 <label htmlFor="name">Nome do administrador</label><input id="name" name="name" required maxLength={120} autoComplete="name"/>
 <label htmlFor="email">Email do administrador</label><input id="email" name="email" type="email" required maxLength={254} autoComplete="email"/>
 {state.error&&<p className="notice error" role="alert">{state.error}</p>}
 {state.message&&<p className="notice" role="status">{state.message}</p>}
 <button className="primary" disabled={pending}>{pending?'Cadastrando…':'Cadastrar administrador'}</button></form>
 {state.inviteUrl&&<section className="invite-box"><h3>Convite pessoal</h3><p>Entregue este link somente ao administrador. Ele permite definir a senha da conta e pode ser usado uma vez.</p><label htmlFor="invite">Link do convite</label><input id="invite" type="text" readOnly value={state.inviteUrl} autoComplete="off"/>
 <button className="secondary" onClick={async()=>{try{await navigator.clipboard.writeText(state.inviteUrl!);setCopied(true);}catch{setCopied(false);}}}>{copied?'Link copiado':'Copiar convite'}</button><p className="footnote">O link fica disponível apenas nesta tela. Não foi enviado por email. Se você não o entregou, pode gerar outro convite repetindo o cadastro.</p></section>}
 </div>;
}

