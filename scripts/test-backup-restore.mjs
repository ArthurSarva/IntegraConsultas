// Local, synthetic disaster-recovery rehearsal. Never accepts a database URL.
import assert from 'node:assert/strict';
import {spawnSync} from 'node:child_process';
import {readFile} from 'node:fs/promises';
import {randomBytes} from 'node:crypto';
import {temporaryDatabase, localDockerEndpoint, digest, verifyArchive} from './backup-guards.mjs';

const container = 'supabase_db_IntegraConsultas';
const schemas = ['auth', 'app', 'private', 'api', 'audit'];
const schemaFlags = schemas.flatMap(schema => ['--schema', schema]);
const suffix = randomBytes(6).toString('hex');
const source = temporaryDatabase('ic_backup_source_' + suffix);
const restored = temporaryDatabase('ic_backup_restored_' + suffix);
const created = new Set();
const read = path => readFile(new URL('../' + path, import.meta.url), 'utf8');
const started = Date.now();

function docker(args, input) {
  const result = spawnSync('docker', args, {input, maxBuffer: 64 * 1024 * 1024, timeout: 120000});
  // Do not echo command output: it can contain synthetic Auth/credential columns.
  if (result.error || result.status !== 0) throw new Error(`Local rehearsal command failed (${args[0]}, exit ${result.status ?? 'unavailable'}). No database output is published.`);
  return result.stdout;
}
function pg(command, args, input) {
  return docker(['exec', '-i', '-u', 'postgres', container, command, '-U', 'postgres', ...args], input);
}
function sql(database, statement) {
  if (database !== 'postgres') temporaryDatabase(database);
  return pg('psql', ['-X', '-q', '-A', '-t', '-v', 'ON_ERROR_STOP=1', '-d', database], statement).toString().trim();
}
function extensions(database) {
  sql(database, 'CREATE SCHEMA extensions; CREATE EXTENSION pgcrypto WITH SCHEMA extensions; CREATE EXTENSION "uuid-ossp" WITH SCHEMA extensions; CREATE EXTENSION btree_gist WITH SCHEMA extensions;');
}
function restore(database, bytes, expected) {
  temporaryDatabase(database);
  assert.ok(created.has(database), 'Restore target must have been created by this process');
  verifyArchive(bytes, expected);
  pg('pg_restore', ['--exit-on-error', '--single-transaction', '-d', database], bytes);
}
function tables(database) {
  return JSON.parse(sql(database, `SELECT coalesce(json_agg(format('%I.%I',n.nspname,c.relname) ORDER BY n.nspname,c.relname),'[]') FROM pg_class c JOIN pg_namespace n ON n.oid=c.relnamespace WHERE n.nspname IN ('auth','app','private','api','audit') AND c.relkind='r';`));
}
function snapshot(database) {
  const rows = tables(database).map(table => ({table, ...JSON.parse(sql(database, `SELECT json_build_object('count',count(*),'hash',md5(coalesce(string_agg(to_jsonb(t)::text,E'\n' ORDER BY to_jsonb(t)::text),''))) FROM ${table} t;`))}));
  const sequences = JSON.parse(sql(database, `SELECT coalesce(json_agg(json_build_object('schema',schemaname,'name',sequencename,'last',last_value,'increment',increment_by) ORDER BY schemaname,sequencename),'[]') FROM pg_sequences WHERE schemaname IN ('auth','app','private','api','audit');`));
  // Schema-only archives include policies, grants, ownership, constraints, indexes,
  // triggers and functions. PostgreSQL emits a random psql restriction key.
  const schema = pg('pg_dump', ['-d', database, '--schema-only', ...schemaFlags]).toString().replace(/^\\(?:un)?restrict .*\r?\n/gm, '');
  return {rows, sequences, schema: digest(schema)};
}

try {
  const context = JSON.parse(docker(['context', 'inspect']).toString());
  localDockerEndpoint(process.env.DOCKER_HOST || context[0]?.Endpoints?.docker?.Host);
  const inspection = JSON.parse(docker(['inspect', container]).toString())[0];
  assert.equal(inspection.Name, '/' + container);
  assert.ok(inspection.State.Running);
  const bindings = inspection.HostConfig.PortBindings?.['5432/tcp'] ?? [];
  assert.ok(bindings.some(binding => binding.HostPort === '54322'), 'Expected local Supabase database port');
  assert.equal(sql('postgres', 'SELECT count(*) FROM auth.users;'), '0', 'Run before web fixtures; source schema must have no accounts');
  assert.equal(sql('postgres', 'SELECT count(*) FROM app.clinics;'), '0', 'Run only on an empty disposable local Supabase');

  // Copy structure only from the actual local platform. No operational records,
  // Vault secrets, cron jobs, Storage objects or worker configuration are copied.
  const structure = pg('pg_dump', ['-d', 'postgres', '--format=custom', '--schema-only', ...schemaFlags]);
  for (const database of [source, restored]) {
    sql('postgres', `CREATE DATABASE ${temporaryDatabase(database)} TEMPLATE template0;`);
    created.add(database);
    extensions(database);
  }
  restore(source, structure, digest(structure));
  const suite = (await Promise.all(['assertions','agenda','automations','google','google-sync','whatsapp'].map(name => read('tests/sql/' + name + '.sql')))).join('\n');
  const fixtures = await read('tests/sql/fixtures.sql');
  sql(source, 'BEGIN;\n' + fixtures + '\n' + suite + '\nRESET ROLE; COMMIT;');
  const before = snapshot(source);
  assert.ok(before.rows.find(row => row.table === 'app.patients')?.count > 0);
  assert.ok(before.rows.find(row => row.table === 'app.appointments')?.count > 0);
  assert.ok(before.rows.find(row => row.table === 'audit.events')?.count > 0);
  const archive = pg('pg_dump', ['-d', source, '--format=custom', ...schemaFlags]);
  const checksum = digest(archive);
  restore(restored, archive, checksum);
  assert.deepEqual(snapshot(restored), before, 'All table data, sequences and schema must survive restoration');

  // Re-exercise restored policies/functions under anon/authenticated roles.
  // Reset only fixture rows, inside a rolled-back transaction; the restored
  // dataset is compared again afterwards to prove this check is non-destructive.
  sql(restored, 'BEGIN; TRUNCATE ' + tables(restored).join(',') + ' RESTART IDENTITY CASCADE;\n' + fixtures + '\n' + suite + '\nRESET ROLE; ROLLBACK;');
  assert.deepEqual(snapshot(restored), before, 'Validation must preserve the recovered dataset');
  console.log(JSON.stringify({result:'passed', tables:before.rows.length, rows:before.rows.reduce((total,row) => total + row.count,0), restoredSqlAssertions:(suite.match(/select pg_temp.assert_/g) || []).length, archiveSha256:checksum, elapsedSeconds:Math.round((Date.now()-started)/1000), scope:'synthetic local databases; no hosted backup or live recovery'}, null, 2));
} finally {
  for (const database of [...created].reverse()) {
    sql('postgres', `DROP DATABASE ${temporaryDatabase(database)};`);
    created.delete(database);
  }
}
