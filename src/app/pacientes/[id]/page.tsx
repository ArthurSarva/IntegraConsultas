import {PatientDetail} from '@/components/patient-pages';
export default async function Page({params,searchParams}:{params:Promise<{id:string}>;searchParams:Promise<{salvo?:string}>}){
 return <PatientDetail id={(await params).id} saved={(await searchParams).salvo==='1'}/>;
}
