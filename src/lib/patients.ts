import 'server-only';
import {redirect} from 'next/navigation';
import {workspace} from '@/lib/identity';
export type Patient={id:string;display_name:string;birth_date:string;phone:string;email:string|null;cpf:string|null;version:number;can_edit:boolean};
export type PatientRecord=Pick<Patient,'id'|'display_name'|'birth_date'|'phone'>&{cpf_suffix?:string|null};
export type PatientPermissions={scope:'clinic'|'own';can_write:boolean;doctor_membership:string|null};
export async function patientWorkspace(ownOnly=false){
 const result=await workspace();
 const permission=await result.client.rpc('patient_permissions',{clinic_id:result.clinic.id});
 if(permission.error||!permission.data)redirect('/inicio');
 const permissions=permission.data as PatientPermissions;
 if(ownOnly&&!permissions.doctor_membership)redirect('/inicio');
 return {...result,permissions};
}
export function clinicToday(timezone:string){
 const parts=new Intl.DateTimeFormat('en-US',{timeZone:timezone,year:'numeric',month:'2-digit',day:'2-digit'}).formatToParts(new Date());
 return ['year','month','day'].map(type=>parts.find(p=>p.type===type)!.value).join('-');
}
