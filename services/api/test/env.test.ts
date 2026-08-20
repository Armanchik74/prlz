import assert from "node:assert/strict";
import test from "node:test";
import { loadEnv } from "../src/config/env.js";

const valid = {
  APP_ENV: "test",
  DATABASE_URL: "postgres://user:password@localhost:5432/test",
  JWT_ACCESS_SECRET: "a".repeat(32),
  JWT_REFRESH_SECRET: "b".repeat(32),
  PII_ENCRYPTION_KEY_BASE64: Buffer.alloc(32).toString("base64"),
  PII_LOOKUP_KEY: "c".repeat(32)
};

test("loads validated configuration", () => {
  const env = loadEnv(valid);
  assert.equal(env.APP_ENV, "test");
  assert.equal(env.RESERVATION_TTL_MINUTES, 120);
});

test("rejects a malformed encryption key", () => {
  assert.throws(() => loadEnv({ ...valid, PII_ENCRYPTION_KEY_BASE64: "x".repeat(44) }));
});
