import {AgendaSettings} from '@/components/agenda-pages';
export default async function Page({searchParams}:{searchParams:Promise<{medico?:string}>}){return <AgendaSettings query={await searchParams}/>;}
