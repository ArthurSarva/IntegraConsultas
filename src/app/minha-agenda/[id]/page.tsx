import {AppointmentDetail} from '@/components/agenda-pages';
export default async function Page({params,searchParams}:{params:Promise<{id:string}>;searchParams:Promise<{salvo?:string;google?:string}>}){const query=await searchParams;return <AppointmentDetail ownOnly id={(await params).id} saved={query.salvo==='1'} googleUnavailable={query.google==='indisponivel'}/>;}
