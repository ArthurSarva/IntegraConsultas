// Structural placeholder. No challenge, credential, body ingestion or state change.
const unavailable=()=>Response.json({status:'inactive'},{status:503,headers:{'Cache-Control':'no-store','Retry-After':'86400'}});
export async function GET(){return unavailable();}
export async function POST(){return unavailable();}

