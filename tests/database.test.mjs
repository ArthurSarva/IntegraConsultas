import {test} from 'node:test';
import assert from 'node:assert/strict';
import {readFile,readdir} from 'node:fs/promises';
import {PGlite} from '@electric-sql/pglite';
import {btree_gist} from '@electric-sql/pglite/contrib/btree_gist';
const read = path => readFile(new URL('../'+path, import.meta.url), 'utf8');

test('schema, isolation, authorization, MFA and session context', async () => {
  const db = new PGlite({extensions:{btree_gist}});
  try {
    await db.exec(await read('tests/support/auth.sql'));
    for (const filename of (await readdir(new URL('../supabase/migrations/', import.meta.url))).filter(n => n.endsWith('.sql')).sort()) {
      await db.exec(await read('supabase/migrations/'+filename));
    }
    await db.exec('begin');
    await db.exec(await read('tests/sql/fixtures.sql'));
    const suite = await read('tests/sql/assertions.sql')+'\n'+await read('tests/sql/agenda.sql')+'\n'+await read('tests/sql/automations.sql')+'\n'+await read('tests/sql/google.sql')+'\n'+await read('tests/sql/google-sync.sql');
    await db.exec(suite);
    const count = (suite.match(/select pg_temp.assert_/g) || []).length;
    assert.ok(count >= 30);
    console.log(count+' SQL assertions passed under actual PostgreSQL roles');
    await db.exec('rollback');
    assert.equal((await db.query('select count(*)::int as count from app.users')).rows[0].count, 0);
  } finally { await db.close(); }
});
