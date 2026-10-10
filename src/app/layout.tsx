import type {Metadata} from 'next';
import {connection} from 'next/server';
import './globals.css';
export const metadata:Metadata={title:'IntegraConsultas',description:'Agenda e organização da sua clínica',robots:{index:false,follow:false}};
export default async function RootLayout({children}:{children:React.ReactNode}) {
  await connection();
  return <html lang="pt-BR"><body><a className="skip" href="#conteudo">Ir para o conteúdo</a>{children}</body></html>;
}

