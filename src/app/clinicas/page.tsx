import Link from 'next/link';import {authorized} from '@/lib/identity';import {selectClinic,logout} from '@/app/actions';import {ActionForm} from '@/components/form';import {AuthShell} from '@/components/shell';
type Clinic={id:string;name:string;timezone:string};
export default async function Clinics({searchParams}:{searchParams:Promise<{criada?:string}>}){
 const query=await searchParams;
 const {client,profile}=await authorized();
 const {data,error}=await client.rpc('list_clinics'); if(error)throw new Error('Unable to list clinics');
 const clinics=(data??[]) as Clinic[];
 return <AuthShell title="Escolha sua clínica" description={profile.is_dev?'Selecione uma clínica para consultar seus dados separadamente.':'Você pode acessar somente as clínicas vinculadas à sua conta.'}>
 <p className="welcome">Olá, {profile.display_name}.</p>
 {query.criada==='sim'&&<p className="notice" role="status">Clínica cadastrada. Selecione-a para vincular os administradores.</p>}
 {clinics.length?<ActionForm action={selectClinic} label="Acessar clínica"><label htmlFor="clinic">Clínica</label><select id="clinic" name="clinic" required defaultValue=""><option value="" disabled>Selecione uma clínica</option>{clinics.map(c=><option key={c.id} value={c.id}>{c.name}</option>)}</select></ActionForm>:<div className="notice"><strong>Nenhuma clínica disponível</strong><p>{profile.is_dev?'As clínicas serão cadastradas na próxima etapa administrativa.':'Solicite à administração o vínculo com sua clínica.'}</p></div>}
 {profile.is_dev&&<Link className="text-link" href="/dev/clinicas/nova">Cadastrar clínica</Link>}
 <form action={logout}><button className="quiet">Sair da conta</button></form></AuthShell>;
}
