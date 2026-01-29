import crypto from 'crypto';
import { getDataEncryptionKey } from '../config/secrets.js';

const PREFIX_V1 = 'enc:v1:';

function deriveKey(secret: string, salt: Buffer) {
  return crypto.scryptSync(secret, salt, 32);
}

export function encryptSecret(plaintext: string): string {
  const salt = crypto.randomBytes(16);
  const iv = crypto.randomBytes(12);
  const key = deriveKey(getDataEncryptionKey(), salt);
  const cipher = crypto.createCipheriv('aes-256-gcm', key, iv);
  const ciphertext = Buffer.concat([cipher.update(plaintext, 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  const packed = Buffer.concat([salt, iv, tag, ciphertext]).toString('base64');
  return `${PREFIX_V1}${packed}`;
}

export function decryptSecret(encrypted: string): string {
  if (!encrypted.startsWith(PREFIX_V1)) {
    throw new Error('Unsupported secret format');
  }
  const raw = Buffer.from(encrypted.slice(PREFIX_V1.length), 'base64');
  const salt = raw.subarray(0, 16);
  const iv = raw.subarray(16, 28);
  const tag = raw.subarray(28, 44);
  const ciphertext = raw.subarray(44);
  const key = deriveKey(getDataEncryptionKey(), salt);
  const decipher = crypto.createDecipheriv('aes-256-gcm', key, iv);
  decipher.setAuthTag(tag);
  const plaintext = Buffer.concat([decipher.update(ciphertext), decipher.final()]).toString('utf8');
  return plaintext;
}

export function decryptSecretAllowLegacy(encrypted: string): string {
  if (encrypted.startsWith(PREFIX_V1)) {
    return decryptSecret(encrypted);
  }

  const [ivHex, ciphertextHex] = encrypted.split(':');
  if (!ivHex || !ciphertextHex) {
    throw new Error('Unsupported secret format');
  }

  const iv = Buffer.from(ivHex, 'hex');
  const key = crypto.scryptSync(getDataEncryptionKey(), 'salt', 32);
  const decipher = crypto.createDecipheriv('aes-256-cbc', key, iv);
  let decrypted = decipher.update(ciphertextHex, 'hex', 'utf8');
  decrypted += decipher.final('utf8');
  return decrypted;
}

