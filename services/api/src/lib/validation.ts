import type { ZodSchema } from "zod";
import { HttpError } from "./errors.js";

export function parse<T>(schema: ZodSchema<T>, value: unknown): T {
  const result = schema.safeParse(value);
  if (!result.success) {
    throw new HttpError(400, "VALIDATION_ERROR", "Проверьте параметры запроса");
  }
  return result.data;
}
