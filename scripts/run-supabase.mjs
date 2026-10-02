import {spawnSync} from 'node:child_process';
import {fileURLToPath} from 'node:url';
const cli = fileURLToPath(new URL('../node_modules/supabase/dist/supabase.js', import.meta.url));
const result = spawnSync(process.execPath, [cli, ...process.argv.slice(2)], {
  encoding: 'utf8', maxBuffer: 16 * 1024 * 1024,
  env: {...process.env,
    SUPABASE_HOME: process.env.SUPABASE_HOME || fileURLToPath(new URL('../.supabase-home/',import.meta.url)),
    SUPABASE_TELEMETRY_DISABLED: process.env.SUPABASE_TELEMETRY_DISABLED || '1'}
});
process.stdout.write(result.stdout || '');
process.stderr.write(result.stderr || '');
if (result.error) { console.error(result.error.message); process.exit(1); }
// CLI 2.119.0 can report a structured connection error with process status 0.
const structuredFailure = (result.stdout || '').split('\n').some(line => {
  try { const message = JSON.parse(line); return message._tag === 'Error' || !!message.error; }
  catch { return false; }
});
process.exit(structuredFailure ? 1 : (result.status ?? 1));

