export type PatientValues={name:string;birth:string;phone:string;email:string;cpf:string};
export function validCpf(value:string){
 if(!/^\d{11}$/.test(value)||/^(\d)\1{10}$/.test(value))return false;
 for(const stage of [10,11]){
  let sum=0;for(let i=0;i<stage-1;i++)sum+=Number(value[i])*(stage-i);
  const digit=(sum*10)%11;
  if((digit===10?0:digit)!==Number(value[stage-1]))return false;
 }
 return true;
}
export function patientInput(values:PatientValues,today:string):{error:string}|{name:string;birth:string;phone:string;email:string|null;cpf:string|null}{
 const name=values.name.trim().replace(/\s+/g,' '),email=values.email.trim().toLowerCase();
 if(!name||name.length>120||/[\u0000-\u001f]/.test(name))return {error:'Informe um nome de até 120 caracteres.'};
 const date=new Date(values.birth+'T00:00:00Z');
 if(!/^\d{4}-\d{2}-\d{2}$/.test(values.birth)||values.birth<'0001-01-01'||!Number.isFinite(date.getTime())||date.toISOString().slice(0,10)!==values.birth||values.birth>today)return {error:'Informe uma data de nascimento válida, sem data futura.'};
 if(values.phone.length>40||!/^[+\d\s().-]+$/.test(values.phone)||!/^\+?[\d\s().-]+$/.test(values.phone.trim()))return {error:'Informe um telefone válido, com DDD ou código do país.'};
 let digits=values.phone.replace(/\D/g,'');
 if(!values.phone.trim().startsWith('+')&&[10,11].includes(digits.length))digits='55'+digits;
 const phone='+'+digits;
 if(!/^\+[1-9]\d{7,14}$/.test(phone))return {error:'Informe um telefone válido, com DDD ou código do país.'};
 if(email&&(email.length>254||!/^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email)))return {error:'Informe um email válido ou deixe o campo vazio.'};
 const cpf=values.cpf.replace(/[.\-\s]/g,'');
 if(cpf&&(!validCpf(cpf)||values.cpf.length>20))return {error:'Informe um CPF válido ou deixe o campo vazio.'};
 return {name,birth:values.birth,phone,email:email||null,cpf:cpf||null};
}
