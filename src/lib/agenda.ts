import 'server-only';
import {redirect} from 'next/navigation';
import {workspace} from '@/lib/identity';
import type {PatientPermissions} from '@/lib/patients';
import type {AgendaDoctor} from '@/lib/agenda-shared';
export * from '@/lib/agenda-shared';
export async function agendaWorkspace(ownOnly=false){
 const result=await workspace();const response=await result.client.rpc('agenda_permissions',{clinic_id:result.clinic.id});
 if(response.error||!response.data)redirect('/inicio');const permissions=response.data as PatientPermissions;
 if(ownOnly&&!permissions.doctor_membership)redirect('/inicio');
 if(!ownOnly&&permissions.scope==='own')redirect('/minha-agenda');
 const doctors=await result.client.rpc('agenda_doctors',{clinic_id:result.clinic.id,own_only:ownOnly});
 if(doctors.error)throw new Error('Unable to list agenda professionals');
 return {...result,permissions,doctors:(doctors.data??[]) as AgendaDoctor[],path:ownOnly?'/minha-agenda':'/agenda'};
}
