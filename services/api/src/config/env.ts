import { z } from "zod";

const schema = z.object({
  APP_ENV: z.enum(["development", "test", "production"]).default("development"),
  PORT: z.coerce.number().int().min(1).max(65535).default(3000),
  LOG_LEVEL: z.enum(["fatal", "error", "warn", "info", "debug", "trace", "silent"]).default("info"),
  DATABASE_URL: z.string().url(),
  JWT_ACCESS_SECRET: z.string().min(32),
  JWT_REFRESH_SECRET: z.string().min(32),
  JWT_ISSUER: z.string().min(3).default("city-marketplace-api"),
  JWT_AUDIENCE: z.string().min(3).default("city-marketplace-mobile"),
  PII_ENCRYPTION_KEY_BASE64: z.string().min(44),
  PII_LOOKUP_KEY: z.string().min(32),
  CORS_ORIGINS: z.string().default(""),
  RESERVATION_TTL_MINUTES: z.coerce.number().int().min(15).max(1440).default(120),
  DATA_RETENTION_DAYS: z.coerce.number().int().min(30).default(1095)
});

export type Env = z.infer<typeof schema>;

export function loadEnv(source: NodeJS.ProcessEnv = process.env): Env {
  const result = schema.safeParse(source);
  if (!result.success) {
    const fields = result.error.issues.map((issue) => issue.path.join(".")).join(", ");
    throw new Error(`Invalid environment configuration: ${fields}`);
  }
  const piiKey = Buffer.from(result.data.PII_ENCRYPTION_KEY_BASE64, "base64");
  if (piiKey.length !== 32) throw new Error("PII_ENCRYPTION_KEY_BASE64 must decode to 32 bytes");
  if (result.data.APP_ENV === "production" &&
      [result.data.JWT_ACCESS_SECRET, result.data.PII_LOOKUP_KEY].some((value) => value.includes("change-me"))) {
    throw new Error("Production secrets must be replaced");
  }
  return result.data;
}
