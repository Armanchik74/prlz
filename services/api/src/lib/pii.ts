import { createCipheriv, createDecipheriv, createHmac, randomBytes } from "node:crypto";

export class PiiCipher {
  private readonly key: Buffer;

  constructor(base64Key: string, private readonly lookupKey: string) {
    this.key = Buffer.from(base64Key, "base64");
    if (this.key.length !== 32) throw new Error("PII encryption key must contain 32 bytes");
  }

  encrypt(value: string): Buffer {
    const nonce = randomBytes(12);
    const cipher = createCipheriv("aes-256-gcm", this.key, nonce);
    const ciphertext = Buffer.concat([cipher.update(value, "utf8"), cipher.final()]);
    return Buffer.concat([nonce, cipher.getAuthTag(), ciphertext]);
  }

  decrypt(value: Buffer | null): string | null {
    if (!value) return null;
    const nonce = value.subarray(0, 12);
    const tag = value.subarray(12, 28);
    const decipher = createDecipheriv("aes-256-gcm", this.key, nonce);
    decipher.setAuthTag(tag);
    return Buffer.concat([decipher.update(value.subarray(28)), decipher.final()]).toString("utf8");
  }

  lookupHash(value: string): string {
    return createHmac("sha256", this.lookupKey).update(value.trim().toLowerCase()).digest("hex");
  }
}
