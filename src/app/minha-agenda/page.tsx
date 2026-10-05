import {AgendaIndex} from '@/components/agenda-pages';
export default async function Page({searchParams}:{searchParams:Promise<{data?:string;pagina?:string}>}){return <AgendaIndex ownOnly query={await searchParams}/>;}
