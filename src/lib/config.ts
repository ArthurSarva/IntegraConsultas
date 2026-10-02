export function supabaseConfig() {
  const url=process.env.NEXT_PUBLIC_SUPABASE_URL;
  const key=process.env.NEXT_PUBLIC_SUPABASE_PUBLISHABLE_KEY;
  if (!url || !key) throw new Error('Supabase environment is not configured');
  return {url,key};
}
export function appOrigin() {
  const origin=process.env.APP_ORIGIN;
  if (!origin) throw new Error('APP_ORIGIN is required');
  const url=new URL(origin);
  if (url.protocol!=='https:' && !(url.protocol==='http:' && ['localhost','127.0.0.1'].includes(url.hostname))) throw new Error('APP_ORIGIN must use HTTPS');
  if (url.pathname!=='/' || url.search || url.hash) throw new Error('APP_ORIGIN must be an origin');
  return url.origin;
}
