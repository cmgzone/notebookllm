import { decryptSecret, decryptSecretAllowLegacy, encryptSecret } from '../services/secretEncryptionService.js';

describe('secretEncryptionService', () => {
  it('encrypts and decrypts roundtrip', () => {
    const plaintext = 'sk_test_123456';
    const encrypted = encryptSecret(plaintext);
    expect(encrypted).not.toBe(plaintext);
    expect(encrypted.startsWith('enc:v1:')).toBe(true);
    expect(decryptSecret(encrypted)).toBe(plaintext);
  });

  it('decryptSecretAllowLegacy rejects unknown format', () => {
    expect(() => decryptSecretAllowLegacy('not-a-secret')).toThrow();
  });
});

