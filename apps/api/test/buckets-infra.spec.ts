import { FILE_BUCKETS } from '@diamoraa/shared';
import { readFileSync } from 'node:fs';
import { join } from 'node:path';

/**
 * Every bucket the API writes to must be created, granted to the app identity and backed up. A bucket missing from the
 * MinIO provisioning is invisible in tests (memory storage) but fails in production with «Access Denied» (chat files did).
 */
describe('object storage buckets are provisioned and backed up', () => {
  const buckets = (file: string) => {
    const m = /^BUCKETS="([^"]+)"/m.exec(readFileSync(join(__dirname, '../../..', file), 'utf8'));
    return (m?.[1] ?? '').split(/\s+/).filter(Boolean).sort();
  };
  it.each(['infra/minio/minio-init.sh', 'infra/backup/minio-backup.sh'])('%s lists every FILE_BUCKETS entry', (file) => {
    expect(buckets(file)).toEqual([...FILE_BUCKETS].sort());
  });
});
