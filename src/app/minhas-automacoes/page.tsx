import {AutomationPage} from '@/components/automation-page';
export default async function Page({searchParams}:{searchParams:Promise<{pagina?:string;consulta?:string}>}){return <AutomationPage ownOnly query={await searchParams}/>;}
