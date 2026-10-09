import {createHash, timingSafeEqual} from 'node:crypto';

export function temporaryDatabase(name) {
  if (!/^ic_backup_(source|restored)_[a-f0-9]{12}$/.test(name)) throw new Error('Database is not an owned temporary rehearsal target');
  return name;
}

export function localDockerEndpoint(endpoint) {
  if (!/^(unix:\/\/\/[^\s]+|npipe:\/\/\/[^\s]+)$/.test(endpoint ?? '')) throw new Error('Rehearsal requires a local Docker socket');
}

export const digest = bytes => createHash('sha256').update(bytes).digest('hex');
export function verifyArchive(bytes, expected) {
  if (!/^[a-f0-9]{64}$/.test(expected ?? '') || !timingSafeEqual(Buffer.from(digest(bytes), 'hex'), Buffer.from(expected, 'hex'))) throw new Error('Backup integrity check failed');
}
