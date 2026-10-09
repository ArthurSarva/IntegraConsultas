import 'server-only';
import type {SupabaseClient} from '@supabase/supabase-js';
import {passwordMode} from '@/lib/security-policy';
export async function passwordSecurity(client:Pick<SupabaseClient,'auth'>,userId:string){
 const [factors,verified]=await Promise.all([client.auth.mfa.listFactors(),client.auth.getClaims()]);
 if(factors.error||verified.error||!verified.data||verified.data.claims.sub!==userId)throw new Error('Unable to verify password access');
 const factor=factors.data.totp.find(f=>f.status==='verified');
 return {mode:passwordMode(verified.data.claims,Boolean(factor)),factor};
}

