import {unseal} from '../src/lib/google-core.ts';
import {GoogleProvider,GoogleFailure,renewGoogle} from '../src/lib/google-provider.ts';
export async function googleCycle(client,config){
 async function rpc(name,args={}){const result=await client.rpc(name,args);if(result.error)throw new Error('Worker database operation failed');return result.data;}
 const clinics=await rpc('google_worker_clinics');let processed=0;
 for(const clinic of clinics){
  const tasks=await rpc('google_claim_tasks',{clinic_id:clinic,batch_size:1});
  for(const task of tasks){
   const args={clinic_id:clinic,task_id:task.id,lease_token:task.lease};let outcome='completed';
   try{
    const data=await rpc('google_task_payload',args);if(!data)throw new GoogleFailure('integration_not_configured');
    const token=unseal(data.credential,config.key,'google-token:'+data.clinic+':'+data.membership);
    const access=await renewGoogle(config.clientId,config.clientSecret,token.refresh);
    await new GoogleProvider(access).sync(data,async()=>{
     const fresh=await rpc('google_task_payload',args);return !!fresh&&fresh.version===data.version&&fresh.calendar===data.calendar&&fresh.credential===data.credential&&fresh.connected_at===data.connected_at;
    });
   }catch(error){outcome=error instanceof GoogleFailure?error.outcome:'transient_failure';}
   await rpc('google_finish_task',{...args,outcome});processed++;
  }
  if(processed>=3)break;
 }
 return processed;
}
