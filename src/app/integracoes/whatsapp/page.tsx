import Link from 'next/link';
import {workspace} from '@/lib/identity';
import {redirect} from 'next/navigation';
import {WorkspaceHeader} from '@/components/workspace-header';
import {WhatsAppChannelForm,type WhatsAppChannel} from '@/components/whatsapp-forms';
export default async function WhatsAppPage({searchParams}:{searchParams:Promise<{salvo?:string}>}){
 const ctx=await workspace(),query=await searchParams;
 const guard=await ctx.client.rpc('team_clinic_context',{clinic_id:ctx.clinic.id});if(guard.error)redirect('/inicio');
 const response=await ctx.client.rpc('whatsapp_channel',{clinic_id:ctx.clinic.id});if(response.error)throw new Error('Unable to read WhatsApp configuration');
 const channel=response.data as WhatsAppChannel;
 return <div className="workspace"><WorkspaceHeader clinic={ctx.clinic.name}/><main id="conteudo"><p className="eyebrow">{ctx.clinic.name}</p><h1>WhatsApp da clínica</h1><p className="notice">Envios desativados. Esta etapa prepara a configuração; não conecta o número nem envia mensagens.</p>{query.salvo&&<p role="status" className="notice">Configuração salva nesta clínica. Os envios continuam desativados.</p>}<section className="module-card"><h2>Canal da clínica</h2><WhatsAppChannelForm key={channel.version} clinic={ctx.clinic.id} channel={channel}/></section><p>Alterações de número criam uma nova versão e preservam o histórico. Credenciais reais serão configuradas posteriormente em ambiente protegido.</p><Link href="/inicio" className="text-link">Voltar ao início</Link></main></div>;
}

