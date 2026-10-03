'use client';
import {useActionState} from 'react';
import {cancelAdministratorInvitation} from '@/app/dev/actions';
import {initial} from '@/components/form';
export function CancelInvitationForm({clinicId,userId,operation,retry=false}:{clinicId:string;userId:string;operation:string;retry?:boolean}){
 const [state,action,pending]=useActionState(cancelAdministratorInvitation,initial);
 return <form action={action} className="cancel-invitation">
 <input type="hidden" name="clinic" value={clinicId}/><input type="hidden" name="user" value={userId}/><input type="hidden" name="operation" value={operation}/>
 <button className="secondary cancel-button" disabled={pending}>{pending?'Cancelando…':retry?'Concluir cancelamento':'Cancelar convite'}</button>
 {state.error&&<p role="alert" className="notice error">{state.error}</p>}
 {state.message&&<p aria-live="polite" className="notice">{state.message}</p>}
 </form>;
}
