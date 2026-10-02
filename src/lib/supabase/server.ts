import 'server-only';
import {createServerClient} from '@supabase/ssr';
import {cookies} from 'next/headers';
import {supabaseConfig} from '@/lib/config';
export async function createClient() {
  const store=await cookies();
  const {url,key}=supabaseConfig();
  return createServerClient(url,key,{
    db:{schema:'api'}, global:{fetch:(input,init)=>fetch(input,{...init,cache:'no-store'})},
    cookies:{
      getAll:()=>store.getAll(),
      setAll:items=>{
        try { for (const {name,value,options} of items) store.set(name,value,options); }
        catch { /* Server Components cannot write cookies; proxy refreshes them. */ }
      }
    }
  });
}
