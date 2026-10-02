'use client';
import {useActionState} from 'react';
import {enroll,verify} from '@/app/seguranca/actions';
import {ActionForm,initial} from '@/components/form';
export function Mfa({factors}:{factors:{id:string;friendly_name?:string}[]}){
 const [state,setup,pending]=useActionState(enroll,initial);
 const factor=state.factorId??factors[0]?.id;
 return <div>{!factors.length&&!state.factorId&&<form action={setup}><p>Abra seu aplicativo autenticador e prepare-se para adicionar uma conta.</p><button className="primary" disabled={pending}>{pending?'Preparando…':'Configurar autenticador'}</button></form>}
 {state.error&&<p className="notice error" role="alert">{state.error}</p>}
 {state.qr&&<div className="mfa-setup"><p>Escaneie o QR code com seu aplicativo autenticador.</p><img src={state.qr} width="200" height="200" alt="QR code para configurar seu autenticador"/><details><summary>Configurar manualmente</summary><code className="totp-secret">{state.secret}</code></details><p className="footnote">Guarde este segredo com segurança. Ele permite gerar seus códigos.</p></div>}
 {factor&&<ActionForm action={verify} label="Confirmar acesso">{factors.length>1?<><label htmlFor="factor">Autenticador</label><select id="factor" name="factor">{factors.map((f,i)=><option key={f.id} value={f.id}>{f.friendly_name||'Autenticador '+(i+1)}</option>)}</select></>:<input type="hidden" name="factor" value={factor}/>}<label htmlFor="code">Código de verificação</label><input id="code" name="code" autoComplete="one-time-code" inputMode="numeric" pattern="[0-9]{6}" maxLength={6} required placeholder="000000"/></ActionForm>}
 </div>;
}
