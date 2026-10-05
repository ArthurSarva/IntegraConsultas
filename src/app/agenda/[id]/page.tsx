import {AppointmentDetail} from '@/components/agenda-pages';
export default async function Page({params,searchParams}:{params:Promise<{id:string}>;searchParams:Promise<{salvo?:string}>}){return <AppointmentDetail id={(await params).id} saved={(await searchParams).salvo==='1'}/>;}
