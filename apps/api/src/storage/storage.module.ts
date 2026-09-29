import {
  CreateBucketCommand, GetObjectCommand, HeadBucketCommand, PutObjectCommand, S3Client,
} from '@aws-sdk/client-s3';
import { Global, Inject, Injectable, Logger, Module, OnModuleInit } from '@nestjs/common';
import { FILE_BUCKETS } from '@diamoraa/shared';
import { Readable } from 'node:stream';
import { ENV, Env } from '../config/env';

export const STORAGE = Symbol('STORAGE');
/** size = bytes in this response; total = the whole object (differs when a byte range was asked for) */
export interface StoredObject { stream: Readable; contentType?: string; size?: number; total?: number }
export interface ByteRange { start: number; end?: number }

/** Object storage port: production = MinIO on the NAS (S3 API), tests = memory. The domain never sees the SDK (D-015). */
export interface StoragePort {
  ensureBuckets(buckets: readonly string[]): Promise<void>;
  put(bucket: string, key: string, body: Buffer, contentType: string): Promise<void>;
  get(bucket: string, key: string, range?: ByteRange): Promise<StoredObject>;
  /** stream bytes of a known size (large videos never sit in memory) */
  putStream(bucket: string, key: string, body: Readable, size: number, contentType: string): Promise<void>;
  ping(): Promise<void>;
}

export const bucketName = (env: Env, bucket: string) => `${env.S3_BUCKET_PREFIX}${bucket}`;

export class MemoryStorage implements StoragePort {
  readonly objects = new Map<string, { body: Buffer; contentType: string }>();
  async ensureBuckets() {}
  async put(b: string, k: string, body: Buffer, contentType: string) { this.objects.set(`${b}/${k}`, { body, contentType }); }
  async get(b: string, k: string, range?: ByteRange): Promise<StoredObject> {
    const o = this.objects.get(`${b}/${k}`);
    if (!o) throw new Error('NoSuchKey');
    const body = range ? o.body.subarray(range.start, (range.end ?? o.body.length - 1) + 1) : o.body;
    return { stream: Readable.from(body), contentType: o.contentType, size: body.length, total: o.body.length };
  }
  async putStream(b: string, k: string, body: Readable, _size: number, contentType: string) {
    const chunks: Buffer[] = [];
    for await (const c of body) chunks.push(Buffer.from(c as Buffer));
    await this.put(b, k, Buffer.concat(chunks), contentType);
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
  async get(Bucket: string, Key: string, range?: ByteRange): Promise<StoredObject> {
    const Range = range ? `bytes=${range.start}-${range.end ?? ''}` : undefined;
    const o = await this.s3.send(new GetObjectCommand({ Bucket, Key, Range }));
    const total = o.ContentRange ? Number(/\/(\d+)$/.exec(o.ContentRange)?.[1]) : o.ContentLength;
    return { stream: o.Body as Readable, contentType: o.ContentType, size: o.ContentLength, total };
  }
  async putStream(Bucket: string, Key: string, Body: Readable, size: number, ContentType: string) {
    await this.s3.send(new PutObjectCommand({ Bucket, Key, Body, ContentLength: size, ContentType }));
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
