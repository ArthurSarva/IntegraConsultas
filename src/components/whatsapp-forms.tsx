'use client';
import {useActionState} from 'react';
import {saveWhatsAppChannel,saveWhatsAppPreference} from '@/app/integracoes/whatsapp/actions';
export type WhatsAppChannel={version:number;phone?:string;phone_number_id?:string;waba_id?:string;status:string};
export function WhatsAppChannelForm({clinic,channel}:{clinic:string;channel:WhatsAppChannel}){
 const [state,action,pending]=useActionState(saveWhatsAppChannel,{});
 return <form action={action} className="form patient-form"><input type="hidden" name="clinic" value={clinic}/><input type="hidden" name="version" value={channel.version}/><fieldset disabled={pending}>
 <label htmlFor="wa-phone">Número remetente da clínica</label><input id="wa-phone" name="phone" type="tel" required maxLength={16} placeholder="+5511999999999" defaultValue={channel.phone??''}/>
 <p className="field-help">Use +, código do país e DDD. Este cadastro não verifica o número na Meta.</p>
 <label htmlFor="wa-phone-id">Identificador do número na Meta (opcional)</label><input id="wa-phone-id" name="phone_id" maxLength={30} inputMode="numeric" defaultValue={channel.phone_number_id??''}/>
 <label htmlFor="wa-waba">Identificador da conta WhatsApp Business (opcional)</label><input id="wa-waba" name="waba" maxLength={30} inputMode="numeric" defaultValue={channel.waba_id??''}/>
 <label htmlFor="wa-status">Situação da configuração</label><select id="wa-status" name="status" defaultValue={channel.status==='paused'?'paused':'draft'}><option value="draft">Em preparação</option><option value="paused">Pausada</option></select></fieldset>
 {state.error&&<p className="error" role="alert">{state.error}</p>}<button className="primary" disabled={pending}>{pending?'Salvando…':'Salvar configuração sem ativar envios'}</button></form>;
}
export function WhatsAppPreferenceForm({clinic,patient,own,enabled,version,editable}:{clinic:string;patient:string;own:boolean;enabled:boolean;version:number;editable:boolean}){
 const [state,action,pending]=useActionState(saveWhatsAppPreference,{});
 return <section className="module-card"><h2>Lembretes por WhatsApp</h2><p>A preferência começa habilitada ao cadastrar o telefone. Nenhuma mensagem é enviada nesta etapa.</p>
 {editable?<form action={action} className="form patient-form"><input type="hidden" name="clinic" value={clinic}/><input type="hidden" name="patient" value={patient}/><input type="hidden" name="own" value={own?'on':''}/><input type="hidden" name="version" value={version}/><label className="checkbox-label"><input type="checkbox" name="enabled" defaultChecked={enabled} disabled={pending}/> Habilitar lembretes neste cadastro</label>{state.error&&<p className="error" role="alert">{state.error}</p>}{state.message&&<p className="notice" role="status">{state.message}</p>}<button className="secondary" disabled={pending}>Salvar preferência</button></form>:<p>{enabled?'Preferência habilitada':'Preferência desativada'}</p>}</section>;
}

