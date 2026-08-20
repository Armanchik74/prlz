import assert from "node:assert/strict";
import test from "node:test";
import { PiiCipher } from "../src/lib/pii.js";

test("encrypts PII with a random nonce and decrypts it", () => {
  const cipher = new PiiCipher(Buffer.alloc(32, 7).toString("base64"), "lookup-key".repeat(4));
  const first = cipher.encrypt("+79001112233");
  const second = cipher.encrypt("+79001112233");
  assert.notDeepEqual(first, second);
  assert.equal(cipher.decrypt(first), "+79001112233");
});

test("creates a stable keyed lookup hash", () => {
  const cipher = new PiiCipher(Buffer.alloc(32, 7).toString("base64"), "lookup-key".repeat(4));
  assert.equal(cipher.lookupHash(" User "), cipher.lookupHash("user"));
});
