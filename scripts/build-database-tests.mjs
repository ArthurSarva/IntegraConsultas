import {readFile,writeFile,mkdir} from 'node:fs/promises';
const read = path => readFile(new URL('../'+path, import.meta.url), 'utf8');
const directory = new URL('../supabase/tests/', import.meta.url);
await mkdir(directory,{recursive:true});
const sql = [
  'begin;',
  'create extension if not exists pgtap with schema extensions;',
  'set search_path = public, extensions;',
  'select plan(1);',
  await read('tests/sql/fixtures.sql'),
  await read('tests/sql/assertions.sql'),
  await read('tests/sql/agenda.sql'),
  await read('tests/sql/automations.sql'),
  await read('tests/sql/google.sql'),
  "select pass('All foundation SQL assertions passed on real Supabase Auth tables');",
  'select * from finish();',
  'rollback;'
].join('\n');
await writeFile(new URL('base.test.sql',directory),sql);
