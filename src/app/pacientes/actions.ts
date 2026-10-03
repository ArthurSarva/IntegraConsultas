'use server';
import {randomUUID} from 'node:crypto';
import {revalidatePath} from 'next/cache';
import {redirect} from 'next/navigation';
import {patientWorkspace,clinicToday,type PatientRecord} from '@/lib/patients';
import {patientInput,type PatientValues} from '@/lib/patient-input';
export type PatientSearchState={records:PatientRecord[];has_more:boolean;page:number;query:string;error?:string};
export type PatientSaveState={error?:string;duplicates?:PatientRecord[];values?:PatientValues;attempt?:string;revision?:number;conflict?:boolean};
export async function searchPatients(_state:PatientSearchState,data:FormData):Promise<PatientSearchState>{
 const ownOnly=data.get('own')==='on';const {client,clinic}=await patientWorkspace(ownOnly);
 const query=String(data.get('query')??'').trim(),page=Number(data.get('page')??0);
 const empty={records:[],has_more:false,page:0,query:query.slice(0,120)};
 if(String(data.get('clinic')??'')!==clinic.id)return {...empty,error:'A clínica ativa mudou. Atualize a página.'};
 if(query.length>120||(query.length>0&&query.length<3)||!Number.isInteger(page)||page<0||page>10000)return {...empty,error:'Use pelo menos três caracteres para pesquisar.'};
 const result=await client.rpc('search_patients',{clinic_id:clinic.id,search_term:query,page_number:page,own_only:ownOnly});
 if(result.error)return {...empty,error:'Não foi possível pesquisar. Atualize a página e tente novamente.'};
 return {...result.data,query} as PatientSearchState;
}
export async function savePatient(_state:PatientSaveState,data:FormData):Promise<PatientSaveState>{
 const ownOnly=data.get('own')==='on';const {client,clinic,permissions}=await patientWorkspace(ownOnly);
 const values:PatientValues={name:String(data.get('name')??'').slice(0,121),birth:String(data.get('birth')??'').slice(0,11),phone:String(data.get('phone')??'').slice(0,41),email:String(data.get('email')??'').slice(0,255),cpf:String(data.get('cpf')??'').slice(0,21)};
 const revision=Number(data.get('revision')??0),base={values,attempt:randomUUID(),revision};
 if(String(data.get('clinic')??'')!==clinic.id)return {...base,error:'A clínica ativa mudou. Atualize a página antes de salvar.'};
 if(!permissions.can_write)return {...base,error:'Seu perfil permite somente consultar os pacientes vinculados a você.'};
 const input=patientInput(values,clinicToday(clinic.timezone));if('error' in input)return {...base,error:input.error};
 const id=String(data.get('patient')??''),version=id?Number(data.get('version')):null,operation=String(data.get('operation')??'');
 if(!/^[0-9a-f-]{36}$/i.test(operation)||(id&&(!/^[0-9a-f-]{36}$/i.test(id)||!Number.isInteger(version)||version!<1)))return {...base,error:'Atualize a página antes de salvar.'};
 const result=await client.rpc('save_patient',{clinic_id:clinic.id,patient_id:id||null,display_name:input.name,birth_date:input.birth,phone:input.phone,email:input.email,cpf:input.cpf,expected_version:version,allow_duplicate:data.get('duplicate')==='on',own_only:ownOnly,operation_id:operation});
 if(result.error)return {...base,error:'Não foi possível salvar. Confira os dados, seu acesso e a clínica ativa.'};
 if(result.data.status==='cpf_duplicate')return {...base,error:'Já existe um paciente com esse CPF nesta clínica. Pesquise o cadastro ou peça ajuda à recepção ou administração.'};
 if(result.data.status==='possible_duplicate')return {...base,duplicates:result.data.matches as PatientRecord[]};
 if(result.data.status==='conflict')return {...base,error:'Este cadastro foi alterado por outra pessoa. Atualize a página, confira os dados e tente novamente.',conflict:true};
 if(result.data.status!=='saved')return {...base,error:'Não foi possível salvar. Tente novamente.'};
 revalidatePath('/pacientes');revalidatePath('/meus-pacientes');
 revalidatePath('/pacientes/'+result.data.id);revalidatePath('/meus-pacientes/'+result.data.id);
 redirect((ownOnly?'/meus-pacientes/':'/pacientes/')+result.data.id+'?salvo=1');
}
