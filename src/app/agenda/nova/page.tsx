import {AppointmentNew} from '@/components/agenda-pages';
export default async function Page({searchParams}:{searchParams:Promise<{data?:string;medico?:string}>}){return <AppointmentNew query={await searchParams}/>;}
