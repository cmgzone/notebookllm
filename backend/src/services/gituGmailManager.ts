import axios from 'axios';
import pool from '../config/database.js';

const GOOGLE_AUTH_BASE = 'https://accounts.google.com/o/oauth2/v2/auth';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';
const GMAIL_SCOPE = encodeURIComponent('https://www.googleapis.com/auth/gmail.readonly https://www.googleapis.com/auth/gmail.send');

function getEnv(name: string, fallback?: string) {
  const v = process.env[name];
  if (v && v.length > 0) return v;
  if (fallback) return fallback;
  throw new Error(`${name} not configured`);
}

class GituGmailManager {
  getAuthUrl(state: string) {
    const clientId = getEnv('GMAIL_CLIENT_ID');
    const redirectUri = encodeURIComponent(getEnv('GMAIL_REDIRECT_URI'));
    const authUrl =
      `${GOOGLE_AUTH_BASE}?client_id=${clientId}` +
      `&redirect_uri=${redirectUri}` +
      `&response_type=code` +
      `&access_type=offline` +
      `&prompt=consent` +
      `&scope=${GMAIL_SCOPE}` +
      `&state=${state}`;
    return authUrl;
  }

  async exchangeCodeForToken(code: string) {
    const clientId = getEnv('GMAIL_CLIENT_ID');
    const clientSecret = getEnv('GMAIL_CLIENT_SECRET');
    const redirectUri = getEnv('GMAIL_REDIRECT_URI');

    const res = await axios.post(GOOGLE_TOKEN_URL, {
      code,
      client_id: clientId,
      client_secret: clientSecret,
      redirect_uri: redirectUri,
      grant_type: 'authorization_code',
    }, {
      headers: { 'Content-Type': 'application/json' },
      timeout: 30000,
    });

    return res.data as {
      access_token: string;
      refresh_token?: string;
      expires_in: number;
      token_type: string;
      scope: string;
    };
  }

  async connect(userId: string, tokenData: any, email?: string) {
    // Generate an expiry date
    const expiresAt = new Date(Date.now() + (tokenData.expires_in || 3600) * 1000);

    await pool.query(
      `INSERT INTO gitu_gmail_connections (user_id, email, encrypted_access_token, encrypted_refresh_token, expires_at, scopes, connected_at, last_sync_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
       ON CONFLICT (user_id) DO UPDATE SET
         email = COALESCE($2, gitu_gmail_connections.email),
         encrypted_access_token = $3,
         encrypted_refresh_token = COALESCE($4, gitu_gmail_connections.encrypted_refresh_token),
         expires_at = $5,
         scopes = $6,
         last_sync_at = NOW()`,
      [
        userId,
        email || null,
        tokenData.access_token,
        tokenData.refresh_token || null,
        expiresAt,
        tokenData.scope || '',
      ]
    );
  }

  async getConnection(userId: string) {
    const res = await pool.query(
      `SELECT 
         user_id, email, 
         encrypted_access_token as access_token, 
         encrypted_refresh_token as refresh_token, 
         expires_at, scopes, last_sync_at as last_used_at
       FROM gitu_gmail_connections WHERE user_id = $1`,
      [userId]
    );
    return res.rows.length ? res.rows[0] : null;
  }

  async isConnected(userId: string): Promise<boolean> {
    const conn = await this.getConnection(userId);
    return !!conn;
  }

  async disconnect(userId: string): Promise<void> {
    await pool.query(`DELETE FROM gitu_gmail_connections WHERE user_id = $1`, [userId]);
  }
}

export const gituGmailManager = new GituGmailManager();
export default gituGmailManager;
