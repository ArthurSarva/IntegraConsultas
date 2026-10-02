import Link from 'next/link';
export function Brand(){return <Link href="/" className="brand"><span className="brand-mark" aria-hidden="true">+</span>Integra<span>Consultas</span></Link>;}
export function AuthShell({title,description,children}:{title:string;description:string;children:React.ReactNode}) {
 return <div className="auth-layout"><aside className="auth-aside"><Brand/><div><p className="eyebrow">TEMPO PARA CUIDAR</p><h1>Sua clínica.<br/>Tudo no lugar.</h1><p>Uma agenda organizada começa com um acesso seguro.</p></div><small>IntegraConsultas · Desenvolvimento</small></aside><main id="conteudo" className="auth-main"><div className="auth-card"><div className="mobile-brand"><Brand/></div><h2>{title}</h2><p className="muted">{description}</p>{children}</div></main></div>;
}
