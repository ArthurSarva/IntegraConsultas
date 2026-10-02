'use client';
import {useEffect,useState} from 'react';import {ActionForm} from '@/components/form';import {acceptInvite} from '@/app/convite/actions';
export function Invite(){const [token,setToken]=useState<string|null>(null);
 useEffect(()=>{const p=new URLSearchParams(window.location.hash.slice(1));const value=p.get('token')??'';window.history.replaceState(null,'','/convite');setToken(value);},[]);
 if(token===null)return <p className="notice">Preparando convite…</p>;
 if(!token)return <p className="notice error" role="alert">Não encontramos um convite válido. Solicite um novo link ao responsável.</p>;
 return <ActionForm action={acceptInvite} label="Aceitar convite"><input type="hidden" name="token" value={token}/><p>Este convite é pessoal. Aceite somente se você foi indicado para administrar a clínica.</p></ActionForm>;
}

