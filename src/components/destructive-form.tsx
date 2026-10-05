'use client';
import {useActionState,useState} from 'react';
import type {FormState} from '@/components/form';
export function DestructiveForm({action,label,description,fields}:{action:(state:FormState,data:FormData)=>Promise<FormState>;label:string;description:string;fields:Record<string,string>}){
 const [open,setOpen]=useState(false),[state,submit,pending]=useActionState(action,{});
 return <div className="destructive-action">
 {!open?<button type="button" className="secondary danger-button" onClick={()=>setOpen(true)}>{label}</button>:<form action={submit} className="destructive-confirm" aria-label={label}>
 {Object.entries(fields).map(([name,value])=><input key={name} type="hidden" name={name} value={value}/>)}
 <p>{description}</p><label className="checkbox-label"><input type="checkbox" name="confirm" required disabled={pending}/>Entendi e confirmo esta ação</label>
 {state.error&&<p className="notice error" role="alert">{state.error}</p>}
 {state.message&&<p className="notice" role="status">{state.message}</p>}
 <div className="destructive-buttons"><button className="secondary danger-button" disabled={pending||!!state.message}>{pending?'Aguarde…':label}</button><button type="button" className="secondary" disabled={pending} onClick={()=>setOpen(false)}>Voltar</button></div>
 </form>}
 </div>;
}
