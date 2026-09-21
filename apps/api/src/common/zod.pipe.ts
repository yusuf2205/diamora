import { Body, PipeTransform, Query } from '@nestjs/common';
import { z } from 'zod';

/** Validates AND transforms input (phone -> E.164, "1500000" -> bigint). */
export class ZodValidationPipe<T extends z.ZodType> implements PipeTransform {
  constructor(private readonly schema: T) {}
  transform(value: unknown): z.output<T> {
    return this.schema.parse(value ?? {});
  }
}
export const ZodBody = <T extends z.ZodType>(schema: T) => Body(new ZodValidationPipe(schema));
export const ZodQuery = <T extends z.ZodType>(schema: T) => Query(new ZodValidationPipe(schema));
