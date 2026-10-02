'use client';
import {useActionState} from 'react';
export type FormState={error?:string;message?:string;factorId?:string;qr?:string;secret?:string;inviteUrl?:string};
export const initial:FormState={};
export function ActionForm({action,children,label}:{action:(state:FormState,data:FormData)=>Promise<FormState>;children:React.ReactNode;label:string}) {
  const [state,submit,pending]=useActionState(action,initial);
  return <form action={submit} className="form">{children}
    {state.error && <p className="notice error" role="alert">{state.error}</p>}
    {state.message && <p className="notice" role="status">{state.message}</p>}
    <button className="primary" disabled={pending}>{pending?'Aguarde…':label}</button>
  </form>;
}
