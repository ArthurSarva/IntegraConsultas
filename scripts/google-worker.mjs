// Server-only worker. No tokens, event bodies or provider responses are logged.
import {createClient} from '@supabase/supabase-js';
import {googleCycle} from './google-cycle.mjs';
const env=process.env;
for(const name of ['NEXT_PUBLIC_SUPABASE_URL','SUPABASE_SERVICE_ROLE_KEY','GOOGLE_CLIENT_ID','GOOGLE_CLIENT_SECRET','GOOGLE_TOKEN_ENCRYPTION_KEY'])if(!env[name])throw new Error('Google worker configuration incomplete');
const client=createClient(env.NEXT_PUBLIC_SUPABASE_URL,env.SUPABASE_SERVICE_ROLE_KEY,{db:{schema:'api'},auth:{persistSession:false,autoRefreshToken:false}});
async function cycle(){const processed=await googleCycle(client,{clientId:env.GOOGLE_CLIENT_ID,clientSecret:env.GOOGLE_CLIENT_SECRET,key:env.GOOGLE_TOKEN_ENCRYPTION_KEY});console.log("Google worker cycle completed: "+processed+" tasks.");}
let stopping=false;process.on('SIGINT',()=>{stopping=true;});process.on('SIGTERM',()=>{stopping=true;});
do{try{await cycle();}catch{console.error('Google worker unavailable; next cycle will retry.');}
 if(process.argv.includes('--once')||stopping)break;
 await new Promise(resolve=>{const stop=()=>{clearTimeout(timer);process.off('SIGINT',stop);process.off('SIGTERM',stop);resolve();};const timer=setTimeout(stop,60000);process.once('SIGINT',stop);process.once('SIGTERM',stop);});
}while(!stopping);
