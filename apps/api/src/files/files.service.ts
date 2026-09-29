import { Controller, Get, Global, Header, Headers, Inject, Injectable, Module, Param, ParseUUIDPipe, Query, Res, StreamableFile } from '@nestjs/common';
import type { Response } from 'express';
import { ApiExcludeController } from '@nestjs/swagger';
import type { FileAsset } from '@diamoraa/database';
import type { FileBucket } from '@diamoraa/shared';
import { createHash, createHmac, randomUUID, timingSafeEqual } from 'node:crypto';
import sharp from 'sharp';
import type { Readable } from 'node:stream';
import { Public } from '../common/decorators';
import { AppError, fileRejected, forbidden, notFound } from '../common/errors';
import { ENV, Env } from '../config/env';
import { PrismaService } from '../prisma/prisma.module';
import { STORAGE, StoragePort, StoredObject, bucketName, type ByteRange } from '../storage/storage.module';

export type FileVariant = 'original' | 'thumb';
export interface FileRef { id: string; url: string; thumbUrl: string }
export interface PreparedImage { main: Buffer; thumb: Buffer; sha256: string; width: number; height: number }

const ACCEPTED = new Set(['jpeg', 'png', 'webp']);
const ACCEPTED_VIDEO = new Set(['video/mp4', 'video/quicktime', 'video/webm']);
/** Sniffs the first bytes so the client's declared MIME is never trusted (mirrors the image-magic-bytes check `sharp` does for photos). */
function sniffVideoMime(buf: Buffer): string | null {
  if (buf.length > 12 && buf.toString('ascii', 4, 8) === 'ftyp') return 'video/mp4';
  if (buf.length > 4 && buf[0] === 0x1a && buf[1] === 0x45 && buf[2] === 0xdf && buf[3] === 0xa3) return 'video/webm';
  return null;
}

@Injectable()
export class FilesService {
  constructor(
    private readonly prisma: PrismaService,
    @Inject(STORAGE) private readonly storage: StoragePort,
    @Inject(ENV) private readonly env: Env,
  ) {}

  /** Real image bytes only (client MIME ignored), EXIF/GPS stripped, orientation fixed, max 2560 px. Nothing stored yet. */
  async prepareImage(buffer: Buffer, maxBytes = this.env.MAX_UPLOAD_BYTES): Promise<PreparedImage> {
    if (buffer.length === 0) throw fileRejected('Empty file');
    if (buffer.length > maxBytes) throw fileRejected('File is too large');
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

  /** Video is stored as-is (no thumbnail, no transcode): real bytes are sniffed so a renamed file cannot pass as video. */
  async uploadVideo(p: { bucket: FileBucket; buffer: Buffer; uploadedById?: string; originalName?: string }): Promise<FileAsset> {
    if (p.buffer.length === 0) throw fileRejected('Empty file');
    if (p.buffer.length > this.env.MAX_UPLOAD_BYTES * 20) throw fileRejected('Video is too large');
    const mime = sniffVideoMime(p.buffer);
    if (!mime || !ACCEPTED_VIDEO.has(mime)) throw fileRejected('Only MP4, MOV or WebM videos are accepted');
    const now = new Date();
    const id = randomUUID();
    const ext = mime === 'video/webm' ? 'webm' : mime === 'video/quicktime' ? 'mov' : 'mp4';
    const objectKey = `${now.getUTCFullYear()}/${String(now.getUTCMonth() + 1).padStart(2, '0')}/${id}.${ext}`;
    const bucket = bucketName(this.env, p.bucket);
    await this.storage.put(bucket, objectKey, p.buffer, mime);
    return this.prisma.fileAsset.create({
      data: { bucket: p.bucket, objectKey, mimeType: mime, size: BigInt(p.buffer.length), sha256: createHash('sha256').update(p.buffer).digest('hex'), originalName: p.originalName?.slice(0, 200), uploadedById: p.uploadedById },
    });
  }

  /**
   * Stores bytes as they are (chat video/voice/audio/documents) - from memory or streamed from a file on disk. The caller
   * decides the (safe) MIME type it is served with. `thumb`: a preview picture (a real image, resized) for a video.
   */
  async storeRaw(p: {
    bucket: FileBucket; buffer?: Buffer; stream?: () => Readable; size?: number; sha256?: string; mimeType: string; ext: string;
    uploadedById?: string; originalName?: string; thumb?: Buffer;
  }): Promise<FileAsset> {
    const size = p.buffer?.length ?? p.size ?? 0;
    if (size === 0) throw fileRejected('Empty file');
    const now = new Date();
    const prefix = `${now.getUTCFullYear()}/${String(now.getUTCMonth() + 1).padStart(2, '0')}`;
    const id = randomUUID();
    const objectKey = `${prefix}/${id}.${p.ext}`;
    const bucket = bucketName(this.env, p.bucket);
    if (p.buffer) await this.storage.put(bucket, objectKey, p.buffer, p.mimeType);
    else await this.storage.putStream(bucket, objectKey, p.stream!(), size, p.mimeType);
    let thumbKey: string | null = null;
    if (p.thumb) {
      try {
        const t = await this.prepareImage(p.thumb);
        thumbKey = `${prefix}/${id}_t.jpg`;
        await this.storage.put(bucket, thumbKey, t.thumb, 'image/jpeg');
      } catch { thumbKey = null; /* a broken preview never blocks the video */ }
    }
    return this.prisma.fileAsset.create({
      data: {
        bucket: p.bucket, objectKey, thumbKey, mimeType: p.mimeType, size: BigInt(size),
        sha256: p.sha256 ?? createHash('sha256').update(p.buffer ?? Buffer.alloc(0)).digest('hex'), originalName: p.originalName?.slice(0, 200), uploadedById: p.uploadedById,
      },
    });
  }

  // ---- signed URLs (bearer capability issued only inside already-authorised responses) ----------------------------
  private sig(fileId: string, variant: FileVariant, exp: number) {
    return createHmac('sha256', this.env.FILE_SIGNING_SECRET).update(`${fileId}.${variant}.${exp}`).digest('base64url');
  }
  signedUrl(fileId: string, variant: FileVariant, now = Date.now(), ttlSeconds = this.env.SIGNED_URL_TTL_SECONDS): string {
    const exp = Math.floor(now / 1000) + ttlSeconds;
    return `${this.env.PUBLIC_API_URL.replace(/\/+$/, '')}/v1/files/${fileId}/${variant}?exp=${exp}&sig=${this.sig(fileId, variant, exp)}`;
  }
  /** `ttlSeconds`: a video / voice note keeps playing (and seeking) for a long time - its link must outlive the default 10 min */
  ref(fileId: string | null | undefined, ttlSeconds?: number): FileRef | null {
    return fileId ? { id: fileId, url: this.signedUrl(fileId, 'original', Date.now(), ttlSeconds), thumbUrl: this.signedUrl(fileId, 'thumb', Date.now(), ttlSeconds) } : null;
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
  async open(fileId: string, variant: FileVariant, range?: ByteRange): Promise<StoredObject & { fullSize: number }> {
    const asset = await this.prisma.fileAsset.findUnique({ where: { id: fileId } });
    if (!asset) throw notFound('File');
    const thumb = variant === 'thumb' && asset.thumbKey;
    const fullSize = thumb ? -1 : Number(asset.size);
    try {
      const o = await this.storage.get(bucketName(this.env, asset.bucket), thumb ? asset.thumbKey! : asset.objectKey, thumb ? undefined : range);
      return { ...o, contentType: thumb ? 'image/jpeg' : (o.contentType ?? asset.mimeType), fullSize };
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
  async get(
    @Param('id', new ParseUUIDPipe()) id: string, @Param('variant') variant: string, @Res({ passthrough: true }) res: Response,
    @Query('exp') exp?: string, @Query('sig') sig?: string, @Headers('range') rangeHeader?: string,
  ) {
    const v = this.files.verify(id, variant, exp, sig);
    // «bytes=start-end»: a video / voice note plays while it downloads, and seeking fetches only that part
    const m = rangeHeader ? /^bytes=(\d+)-(\d*)$/.exec(rangeHeader.trim()) : null;
    const range = m ? { start: Number(m[1]), end: m[2] ? Number(m[2]) : undefined } : undefined;
    const o = await this.files.open(id, v, range);
    const type = o.contentType ?? 'application/octet-stream';
    const inline = /^(image\/(jpeg|png|webp)|video\/|audio\/)/.test(type);
    res.setHeader('Accept-Ranges', 'bytes');
    if (range && o.total !== undefined && o.fullSize >= 0) {
      if (range.start >= o.total) { res.status(416).setHeader('Content-Range', `bytes */${o.total}`); o.stream.destroy(); return; }
      const end = range.start + (o.size ?? 0) - 1;
      res.status(206).setHeader('Content-Range', `bytes ${range.start}-${end}/${o.total}`);
    }
    return new StreamableFile(o.stream, { type: inline ? type : 'application/octet-stream', length: o.size, disposition: inline ? 'inline' : 'attachment' });
  }
}

@Global()
@Module({ controllers: [FilesController], providers: [FilesService], exports: [FilesService] })
export class FilesModule {}
