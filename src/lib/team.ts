import 'server-only';
import {redirect} from 'next/navigation';
import {workspace} from '@/lib/identity';
export async function teamWorkspace(){
 const result=await workspace();
 if(!result.profile.is_dev&&!result.clinic.roles.some(r=>r.role==='administrator'))redirect('/inicio');
 const check=await result.client.rpc('team_clinic_context',{clinic_id:result.clinic.id});
 if(check.error||check.data!==result.clinic.id)redirect('/inicio');
 return result;
}
