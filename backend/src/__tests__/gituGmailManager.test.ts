import { gituGmailManager } from '../services/gituGmailManager.js';

describe('GituGmailManager', () => {
  beforeAll(() => {
    process.env.GMAIL_CLIENT_ID = 'test-client-id';
    process.env.GMAIL_CLIENT_SECRET = 'test-secret';
    process.env.GMAIL_REDIRECT_URI = 'http://localhost:3000/api/gitu/gmail/callback';
  });

  test('getAuthUrl contains client_id, redirect_uri and state', () => {
    const state = 'abc123';
    const url = gituGmailManager.getAuthUrl(state);
    expect(url).toContain('client_id=test-client-id');
    expect(url).toContain(encodeURIComponent(process.env.GMAIL_REDIRECT_URI!));
    expect(url).toContain(`state=${state}`);
    expect(url).toContain('scope=');
  });
});
