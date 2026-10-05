export type AgendaDoctor={id:string;name:string;duration:number};
export type Appointment={id:string;doctor:string;doctor_name:string;patient:string;patient_name:string;patient_archived:boolean;starts_at:string;ends_at:string;start_local:string;end_local:string;duration:number;status:string;version:number;replaces_id:string|null;history?:{version:number;status:string;start_local:string;duration:number;occurred_at:string}[]};
export type AgendaBlock={id:string;doctor:string;doctor_name:string;start_local:string;end_local:string;version:number};
export type Availability={id:string;weekday:number;start_time:string;end_time:string;version:number};
export const statuses:Record<string,string>={agendada:'Agendada',confirmada:'Confirmada',concluida:'Concluída',cancelada:'Cancelada',falta:'Falta'};
export const weekdays=['Domingo','Segunda-feira','Terça-feira','Quarta-feira','Quinta-feira','Sexta-feira','Sábado'];
export const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function localDisplay(value:string){const [date,time]=value.split('T');return date.split('-').reverse().join('/')+' às '+time;}
