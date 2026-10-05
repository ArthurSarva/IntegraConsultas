import {AppointmentNew} from '@/components/agenda-pages';
export default async function Page({searchParams}:{searchParams:Promise<{data?:string}>}){return <AppointmentNew ownOnly query={await searchParams}/>;}
