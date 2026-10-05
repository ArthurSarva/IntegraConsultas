import {AgendaIndex} from '@/components/agenda-pages';
export default async function Page({searchParams}:{searchParams:Promise<{data?:string;medico?:string;pagina?:string}>}){return <AgendaIndex query={await searchParams}/>;}
