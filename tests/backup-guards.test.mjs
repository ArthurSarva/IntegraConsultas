import {test} from 'node:test';
import assert from 'node:assert/strict';
import {temporaryDatabase, localDockerEndpoint, digest, verifyArchive} from '../scripts/backup-guards.mjs';

test('cleanup rejects operational databases and SQL injection', () => {
  for (const name of ['postgres', 'template0', 'app', 'ic_backup_source_123', 'ic_backup_source_abcdef123456; DROP DATABASE postgres', 'ic_backup_source_ABCDEF123456']) assert.throws(() => temporaryDatabase(name));
  assert.equal(temporaryDatabase('ic_backup_restored_abcdef123456'), 'ic_backup_restored_abcdef123456');
});
test('rehearsal refuses remote Docker endpoints', () => {
  for (const endpoint of ['tcp://127.0.0.1:2375', 'ssh://production', 'tcp://database.example:2376', '', undefined]) assert.throws(() => localDockerEndpoint(endpoint));
  localDockerEndpoint('unix:///var/run/docker.sock');
  localDockerEndpoint('npipe:////./pipe/docker_engine');
});
test('corrupt, truncated and substituted archives fail before restore', () => {
  const archive = Buffer.from('synthetic archive');
  const expected = digest(archive);
  verifyArchive(archive, expected);
  for (const bytes of [Buffer.from('different archive'), archive.subarray(1), Buffer.alloc(0)]) assert.throws(() => verifyArchive(bytes, expected));
  assert.throws(() => verifyArchive(archive, 'invalid'));
});
