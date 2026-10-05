'use client';
import {useActionState} from 'react';
export type FormState={error?:string;message?:string;factorId?:string;qr?:string;secret?:string;inviteUrl?:string};
export const initial:FormState={};
export function ActionForm({action,children,label,disabled=false}:{action:(state:FormState,data:FormData)=>Promise<FormState>;children:React.ReactNode;label:string;disabled?:boolean}) {
  const [state,submit,pending]=useActionState(action,initial);
  return <form action={submit} className="form">{children}
    {state.error && <p className="notice error" role="alert">{state.error}</p>}
    {state.message && <p className="notice" role="status">{state.message}</p>}
    <button className="primary" disabled={pending||disabled}>{pending?'Aguarde…':label}</button>
  </form>;
}
