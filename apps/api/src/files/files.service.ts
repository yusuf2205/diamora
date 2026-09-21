import { Controller, Get, Global, Header, Inject, Injectable, Module, Param, ParseUUIDPipe, Query, StreamableFile } from '@nestjs/common';
import { ApiExcludeController } from '@nestjs/swagger';
import type { FileAsset } from '@yusmus/database';
import type { FileBucket } from '@yusmus/shared';
import { createHash, createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import sharp from 'sharp';
import { Public } from '../common/decorators';
import { AppError, fileRejected, forbidden, notFound } from '../common/errors';
import { ENV, Env } from '../config/env';
import { PrismaService } from '../prisma/prisma.module';
import { STORAGE, StoragePort, StoredObject, bucketName } from '../storage/storage.module';

export type FileVariant = 'original' | 'thumb';
export interface FileRef { id: string; url: string; thumbUrl: string }
export interface PreparedImage { main: Buffer; thumb: Buffer; sha256: string; width: number; height: number }

const ACCEPTED = new Set(['jpeg', 'png', 'webp']);

@Injectable()
export class FilesService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(STORAGE) private readonly storage: StoragePort,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Real image bytes only (client MIME ignored), EXIF/GPS stripped, orientation fixed, max 2560 px. Nothing stored yet. */
  async prepareImage(buffer: Buffer): Promise<PreparedImage> {
    if (buffer.length === 0) throw fileRejected('Empty file');
    if (buffer.length > this.env.MAX_UPLOAD_BYTES) throw fileRejected('File is too large');
    try {
      const input = sharp(buffer, { failOn: 'error', limitInputPixels: 120_000_000 });
      const meta = await input.metadata();
      if (!meta.format || !ACCEPTED.has(meta.format)) throw fileRejected('Only JPEG, PNG or WebP images are accepted');
      const main = await input.rotate().resize({ width: 2560, height: 2560, fit: 'inside', withoutEnlargement: true })
        .flatten({ background: '#ffffff' }).jpeg({ quality: 85 }).toBuffer({ resolveWithObject: true });
      const thumb = await sharp(main.data).resize({ width: 320, height: 320, fit: 'inside' }).jpeg({ quality: 70 }).toBuffer();
      return { main: main.data, thumb, sha256: createHash('sha256').update(main.data).digest('hex'), width: main.info.width, height: main.info.height };
    } catch (err) {
      if (err instanceof AppError) throw err;
      throw fileRejected('The file is not a valid image');
    }
  }

  async store(p: { bucket: FileBucket; image: PreparedImage; uploadedById?: string; originalName?: string }): Promise<FileAsset> {
    const now = new Date();
    const id = randomUUID();
    const prefix = `${now.getUTCFullYear()}/${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
    const objectKey = `${prefix}/${id}.jpg`;
    const thumbKey = `${prefix}/${id}_t.jpg`;
    const bucket = bucketName(this.env, p.bucket);
    await this.storage.put(bucket, objectKey, p.image.main, 'image/jpeg');
    await this.storage.put(bucket, thumbKey, p.image.thumb, 'image/jpeg');
    return this.prisma.fileAsset.create({
      data: {
        bucket: p.bucket, objectKey, thumbKey, mimeType: 'image/jpeg', size: BigInt(p.image.main.length), sha256: p.image.sha256,
        width: p.image.width, height: p.image.height, originalName: p.originalName?.slice(0, 200), uploadedById: p.uploadedById,
      },
    });
  }

  async uploadImage(p: { bucket: FileBucket; buffer: Buffer; uploadedById?: string; originalName?: string }): Promise<FileAsset> {
    return this.store({ ...p, image: await this.prepareImage(p.buffer) });
  }

  // ---- signed URLs (bearer capability issued only inside already-authorised responses) ----------------------------
  private sig(fileId: string, variant: FileVariant, exp: number) {
    return createHmac('sha256', this.env.FILE_SIGNING_SECRET).update(`${fileId}.${variant}.${exp}`).digest('base64url');
  }
  signedUrl(fileId: string, variant: FileVariant, now = Date.now()): string {
    const exp = Math.floor(now / 1000) + this.env.SIGNED_URL_TTL_SECONDS;
    return `${this.env.PUBLIC_API_URL.replace(/\/+$/, '')}/v1/files/${fileId}/${variant}?exp=${exp}&sig=${this.sig(fileId, variant, exp)}`;
  }
  ref(fileId: string | null | undefined): FileRef | null {
    return fileId ? { id: fileId, url: this.signedUrl(fileId, 'original'), thumbUrl: this.signedUrl(fileId, 'thumb') } : null;
  }
  verify(fileId: string, variant: string, exp?: string, sig?: string): FileVariant {
    if (variant !== 'original' && variant !== 'thumb') throw notFound('File');
    const e = Number(exp);
    if (!sig || !Number.isInteger(e) || e * 1000 < Date.now()) throw forbidden('Link expired or invalid');
    const a = Buffer.from(this.sig(fileId, variant, e));
    const b = Buffer.from(sig);
    if (a.length !== b.length || !timingSafeEqual(a, b)) throw forbidden('Link expired or invalid');
    return variant;
  }
  async open(fileId: string, variant: FileVariant): Promise<StoredObject> {
    const asset = await this.prisma.fileAsset.findUnique({ where: { id: fileId } });
    if (!asset) throw notFound('File');
    try {
      const o = await this.storage.get(bucketName(this.env, asset.bucket), variant === 'thumb' ? (asset.thumbKey ?? asset.objectKey) : asset.objectKey);
      return { ...o, contentType: o.contentType ?? asset.mimeType };
    } catch {
      throw notFound('File content');
    }
  }
}

@ApiExcludeController()
@Controller('files')
export class FilesController {
  constructor(private readonly files: FilesService) {}

  @Public()
  @Get(':id/:variant')
  @Header('X-Content-Type-Options', 'nosniff')
  @Header('Cache-Control', 'private, max-age=300')
  async get(@Param('id', new ParseUUIDPipe()) id: string, @Param('variant') variant: string, @Query('exp') exp?: string, @Query('sig') sig?: string) {
    const o = await this.files.open(id, this.files.verify(id, variant, exp, sig));
    return new StreamableFile(o.stream, { type: o.contentType ?? 'application/octet-stream', length: o.size, disposition: 'inline' });
  }
}

@Global()
@Module({ controllers: [FilesController], providers: [FilesService], exports: [FilesService] })
export class FilesModule {}
