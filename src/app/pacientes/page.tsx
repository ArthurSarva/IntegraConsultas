import {PatientIndex} from '@/components/patient-pages';
export default async function Page({searchParams}:{searchParams:Promise<{removido?:string}>}){const query=await searchParams;return <PatientIndex removed={query.removido}/>;}
