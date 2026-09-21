import {
  CreateBucketCommand, GetObjectCommand, HeadBucketCommand, PutObjectCommand, S3Client,
} from '@aws-sdk/client-s3';
import { Global, Inject, Injectable, Logger, Module, OnModuleInit } from '@nestjs/common';
import { FILE_BUCKETS } from '@yusmus/shared';
import { Readable } from 'node:stream';
import { ENV, Env } from '../config/env';

export const STORAGE = Symbol('STORAGE');
export interface StoredObject { stream: Readable; contentType?: string; size?: number }

/** Object storage port: production = MinIO on the NAS (S3 API), tests = memory. The domain never sees the SDK (D-015). */
export interface StoragePort {
  ensureBuckets(buckets: readonly string[]): Promise<void>;
  put(bucket: string, key: string, body: Buffer, contentType: string): Promise<void>;
  get(bucket: string, key: string): Promise<StoredObject>;
  ping(): Promise<void>;
}

export const bucketName = (env: Env, bucket: string) => `${env.S3_BUCKET_PREFIX}${bucket}`;

export class MemoryStorage implements StoragePort {
  readonly objects = new Map<string, { body: Buffer; contentType: string }>();
  async ensureBuckets() {}
  async put(b: string, k: string, body: Buffer, contentType: string) { this.objects.set(`${b}/${k}`, { body, contentType }); }
  async get(b: string, k: string): Promise<StoredObject> {
    const o = this.objects.get(`${b}/${k}`);
    if (!o) throw new Error('NoSuchKey');
    return { stream: Readable.from(o.body), contentType: o.contentType, size: o.body.length };
  }
  async ping() {}
}

export class S3Storage implements StoragePort {
  private readonly s3: S3Client;
  constructor(env: Env, private readonly probeBucket: string) {
    this.s3 = new S3Client({
      endpoint: env.S3_ENDPOINT, region: env.S3_REGION, forcePathStyle: env.S3_FORCE_PATH_STYLE,
      credentials: { accessKeyId: env.S3_ACCESS_KEY as string, secretAccessKey: env.S3_SECRET_KEY as string },
    });
  }
  async ensureBuckets(buckets: readonly string[]) {
    for (const Bucket of buckets) {
      try { await this.s3.send(new HeadBucketCommand({ Bucket })); } catch { await this.s3.send(new CreateBucketCommand({ Bucket })); }
    }
  }
  async put(Bucket: string, Key: string, Body: Buffer, ContentType: string) { await this.s3.send(new PutObjectCommand({ Bucket, Key, Body, ContentType })); }
  async get(Bucket: string, Key: string): Promise<StoredObject> {
    const o = await this.s3.send(new GetObjectCommand({ Bucket, Key }));
    return { stream: o.Body as Readable, contentType: o.ContentType, size: o.ContentLength };
  }
  async ping() { await this.s3.send(new HeadBucketCommand({ Bucket: this.probeBucket })); }
}

@Injectable()
class StorageBootstrap implements OnModuleInit {
  private readonly log = new Logger('Storage');
  constructor(@Inject(STORAGE) private readonly storage: StoragePort, @Inject(ENV) private readonly env: Env) {}
  async onModuleInit() {
    // production buckets/quotas/credentials are provisioned by the `minio-init` container; auto-create is dev/test only
    if (this.env.S3_AUTO_CREATE_BUCKETS || this.env.STORAGE_DRIVER === 'memory') {
      try { await this.storage.ensureBuckets(FILE_BUCKETS.map((b) => bucketName(this.env, b))); } catch (e) { this.log.warn(`ensureBuckets: ${(e as Error).message}`); }
    }
  }
}

@Global()
@Module({
  providers: [
    { provide: STORAGE, inject: [ENV], useFactory: (env: Env): StoragePort => env.STORAGE_DRIVER === 'memory' ? new MemoryStorage() : new S3Storage(env, bucketName(env, FILE_BUCKETS[0])) },
    StorageBootstrap,
  ],
  exports: [STORAGE],
})
export class StorageModule {}
