import Link from 'next/link';
import {randomUUID} from 'node:crypto';
import {notFound,redirect} from 'next/navigation';
import {patientWorkspace,clinicToday,type Patient} from '@/lib/patients';
import {PatientList} from '@/components/patient-list';
import {PatientForm} from '@/components/patient-form';
import {WorkspaceHeader} from '@/components/workspace-header';
import {DestructiveForm} from '@/components/destructive-form';
import {deletePatient} from '@/app/remocoes/actions';
import {PatientAppointmentHistory} from '@/components/agenda-pages';
import {WhatsAppPreferenceForm} from '@/components/whatsapp-forms';
export async function PatientIndex({ownOnly=false,removed}:{ownOnly?:boolean;removed?:string}){
 const {client,clinic,permissions}=await patientWorkspace(ownOnly);
 const result=await client.rpc('search_patients',{clinic_id:clinic.id,search_term:'',page_number:0,own_only:ownOnly});
 if(result.error)throw new Error('Unable to list patients');
 const path=ownOnly?'/meus-pacientes':'/pacientes';
 return <div className="workspace"><WorkspaceHeader clinic={clinic.name}/><main id="conteudo"><p className="eyebrow">{clinic.name}</p><h1>{ownOnly||permissions.scope==='own'?'Meus pacientes':'Pacientes da clínica'}</h1><p className="muted">{ownOnly||permissions.scope==='own'?'Somente pacientes vinculados a você nesta clínica.':'Cadastros somente da clínica selecionada.'}</p>{removed==='deleted'&&<p role="status" className="notice">Cadastro excluído. A referência de auditoria foi preservada.</p>}{removed==='archived'&&<p role="status" className="notice">Cadastro arquivado para preservar o histórico de consultas.</p>}{permissions.can_write&&<Link href={path+'/novo'} className="primary link-button patient-new">Cadastrar paciente</Link>}<PatientList clinicId={clinic.id} ownOnly={ownOnly} initial={{...result.data,query:''}}/><Link href="/inicio" className="text-link">Voltar ao início</Link></main></div>;
}
export async function PatientNew({ownOnly=false}:{ownOnly?:boolean}){
 const {clinic,permissions}=await patientWorkspace(ownOnly),path=ownOnly?'/meus-pacientes':'/pacientes';
 if(!permissions.can_write)redirect(path);
 return <div className="workspace"><WorkspaceHeader clinic={clinic.name}/><main id="conteudo"><p className="eyebrow">PACIENTES</p><h1>Novo paciente</h1><p className="muted">Cadastre apenas os dados necessários para identificar e contatar o paciente na {clinic.name}.</p><section className="module-card"><PatientForm clinicId={clinic.id} operation={randomUUID()} today={clinicToday(clinic.timezone)} ownOnly={ownOnly}/></section><Link href={path} className="text-link">Voltar aos pacientes</Link></main></div>;
}
export async function PatientDetail({id,ownOnly=false,saved=false}:{id:string;ownOnly?:boolean;saved?:boolean}){
 const {client,clinic,permissions}=await patientWorkspace(ownOnly),path=ownOnly?'/meus-pacientes':'/pacientes';
 if(!/^[0-9a-f-]{36}$/i.test(id))notFound();
 const result=await client.rpc('get_patient',{clinic_id:clinic.id,patient_id:id,own_only:ownOnly});
 if(result.error||!result.data)notFound();
 const patient=result.data as Patient,editable=permissions.can_write&&patient.can_edit;
 const whatsapp=await client.rpc('patient_whatsapp',{clinic_id:clinic.id,patient_id:id,own_only:ownOnly});
 if(whatsapp.error||!whatsapp.data)throw new Error('Unable to verify WhatsApp preference');
 return <div className="workspace"><WorkspaceHeader clinic={clinic.name}/><main id="conteudo"><p className="eyebrow">PACIENTES</p><h1>{editable?'Cadastro do paciente':'Paciente'}</h1><p className="muted">{patient.display_name} · {clinic.name}</p>{saved&&<p className="notice" role="status">Cadastro salvo nesta clínica.</p>}<section className="module-card">{editable?<PatientForm key={patient.id+':'+patient.version} clinicId={clinic.id} operation={randomUUID()} today={clinicToday(clinic.timezone)} patient={patient} ownOnly={ownOnly}/>:<dl className="patient-details"><dt>Nome completo</dt><dd>{patient.display_name}</dd><dt>Data de nascimento</dt><dd>{patient.birth_date.split('-').reverse().join('/')}</dd><dt>Telefone / WhatsApp</dt><dd>{patient.phone}</dd><dt>Email</dt><dd>{patient.email??'Não informado'}</dd><dt>CPF</dt><dd>{patient.cpf??'Não informado'}</dd></dl>}</section>{!editable&&permissions.can_write&&<p className="field-help">Cadastro compartilhado: solicite alterações à recepção da clínica ou à administração.</p>}{permissions.can_write&&permissions.scope==='clinic'&&<section className="module-card removal-card"><h2>Excluir cadastro</h2><DestructiveForm key={patient.id+':delete:'+patient.version} action={deletePatient} label="Excluir cadastro" description={'Excluir o cadastro de '+patient.display_name+' somente da '+clinic.name+'? Sem consultas vinculadas, os dados cadastrais serão apagados. Com histórico de consultas, o cadastro será arquivado. Esta ação não pode ser desfeita pela tela.'} fields={{clinic:clinic.id,target:patient.id,version:String(patient.version),operation:randomUUID()}}/></section>}<WhatsAppPreferenceForm key={whatsapp.data.version} clinic={clinic.id} patient={patient.id} own={ownOnly} enabled={whatsapp.data.enabled} version={whatsapp.data.version} editable={editable}/><PatientAppointmentHistory clinicId={clinic.id} patientId={patient.id} ownOnly={ownOnly||permissions.scope==='own'}/><Link href={path} className="text-link">Voltar aos pacientes</Link></main></div>;
}

