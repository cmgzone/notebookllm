import { buildRawEmail } from '../services/gituGmailOperations.js';

describe('GituGmailOperations', () => {
  test('buildRawEmail produces base64url without padding and includes headers', () => {
    const raw = buildRawEmail('user@example.com', 'Hello', 'Body text', 'me@example.com');
    expect(typeof raw).toBe('string');
    expect(raw.includes('=')).toBe(false); // No padding
    const decoded = Buffer.from(raw.replace(/-/g, '+').replace(/_/g, '/'), 'base64').toString('utf8');
    expect(decoded).toContain('To: user@example.com');
    expect(decoded).toContain('From: me@example.com');
    expect(decoded).toContain('Subject: Hello');
    expect(decoded).toContain('Body text');
  });
});
