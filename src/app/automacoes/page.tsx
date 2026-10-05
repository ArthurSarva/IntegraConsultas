import {AutomationPage} from '@/components/automation-page';
export default async function Page({searchParams}:{searchParams:Promise<{pagina?:string;consulta?:string}>}){return <AutomationPage query={await searchParams}/>;}
