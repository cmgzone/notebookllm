import axios from 'axios';
import pool from '../config/database.js';
import { decryptSecretAllowLegacy, encryptSecret } from './secretEncryptionService.js';

const GOOGLE_AUTH_BASE = 'https://accounts.google.com/o/oauth2/v2/auth';
const GOOGLE_TOKEN_URL = 'https://oauth2.googleapis.com/token';

const CALENDAR_SCOPE = encodeURIComponent(
  'https://www.googleapis.com/auth/calendar.readonly https://www.googleapis.com/auth/calendar.events'
);

function getEnv(name: string, fallback?: string) {
  const v = process.env[name];
  if (v && v.length > 0) return v;
  if (fallback) return fallback;
  throw new Error(`${name} not configured`);
}

type TokenData = {
  access_token: string;
  refresh_token?: string;
  expires_in?: number;
  token_type?: string;
  scope?: string;
};

class GituGoogleCalendarManager {
  getAuthUrl(state: string) {
    const clientId = getEnv('GOOGLE_CALENDAR_CLIENT_ID');
    const redirectUri = encodeURIComponent(getEnv('GOOGLE_CALENDAR_REDIRECT_URI'));
    return (
      `${GOOGLE_AUTH_BASE}?client_id=${clientId}` +
      `&redirect_uri=${redirectUri}` +
      `&response_type=code` +
      `&access_type=offline` +
      `&prompt=consent` +
      `&scope=${CALENDAR_SCOPE}` +
      `&state=${state}`
    );
  }

  async exchangeCodeForToken(code: string): Promise<TokenData> {
    const clientId = getEnv('GOOGLE_CALENDAR_CLIENT_ID');
    const clientSecret = getEnv('GOOGLE_CALENDAR_CLIENT_SECRET');
    const redirectUri = getEnv('GOOGLE_CALENDAR_REDIRECT_URI');

    const res = await axios.post(
      GOOGLE_TOKEN_URL,
      {
        code,
        client_id: clientId,
        client_secret: clientSecret,
        redirect_uri: redirectUri,
        grant_type: 'authorization_code',
      },
      {
        headers: { 'Content-Type': 'application/json' },
        timeout: 30000,
      }
    );

    return res.data as TokenData;
  }

  private async refreshAccessToken(refreshToken: string): Promise<TokenData> {
    const clientId = getEnv('GOOGLE_CALENDAR_CLIENT_ID');
    const clientSecret = getEnv('GOOGLE_CALENDAR_CLIENT_SECRET');

    const res = await axios.post(
      GOOGLE_TOKEN_URL,
      {
        refresh_token: refreshToken,
        client_id: clientId,
        client_secret: clientSecret,
        grant_type: 'refresh_token',
      },
      {
        headers: { 'Content-Type': 'application/json' },
        timeout: 30000,
      }
    );

    return res.data as TokenData;
  }

  async connect(userId: string, tokenData: TokenData, email?: string) {
    const expiresAt =
      typeof tokenData.expires_in === 'number'
        ? new Date(Date.now() + tokenData.expires_in * 1000)
        : new Date(Date.now() + 3600 * 1000);

    const encryptedAccessToken = encryptSecret(tokenData.access_token);
    const encryptedRefreshToken = tokenData.refresh_token ? encryptSecret(tokenData.refresh_token) : null;

    await pool.query(
      `INSERT INTO gitu_google_calendar_connections (user_id, email, encrypted_access_token, encrypted_refresh_token, expires_at, scopes, created_at, updated_at, last_used_at)
       VALUES ($1,$2,$3,$4,$5,$6,NOW(),NOW(),NOW())
       ON CONFLICT (user_id) DO UPDATE SET
         email = COALESCE($2, gitu_google_calendar_connections.email),
         encrypted_access_token = $3,
         encrypted_refresh_token = COALESCE($4, gitu_google_calendar_connections.encrypted_refresh_token),
         expires_at = $5,
         scopes = $6,
         updated_at = NOW(),
         last_used_at = NOW()`,
      [userId, email || null, encryptedAccessToken, encryptedRefreshToken, expiresAt, tokenData.scope || null]
    );
  }

  async getConnection(userId: string): Promise<{
    user_id: string;
    email: string | null;
    access_token: string;
    refresh_token: string | null;
    expires_at: Date | null;
    scopes: string | null;
    created_at: Date;
    updated_at: Date;
    last_used_at: Date | null;
  } | null> {
    const res = await pool.query(
      `SELECT user_id, email, encrypted_access_token, encrypted_refresh_token, expires_at, scopes, created_at, updated_at, last_used_at
       FROM gitu_google_calendar_connections
       WHERE user_id = $1`,
      [userId]
    );
    if (res.rows.length === 0) return null;

    const row = res.rows[0];
    const accessToken = decryptSecretAllowLegacy(row.encrypted_access_token);
    const refreshToken = row.encrypted_refresh_token ? decryptSecretAllowLegacy(row.encrypted_refresh_token) : null;

    const now = Date.now();
    const expiresAtMs = row.expires_at ? new Date(row.expires_at).getTime() : null;
    const isExpiringSoon = expiresAtMs !== null && expiresAtMs - now < 2 * 60 * 1000;

    let finalAccessToken = accessToken;
    let finalExpiresAt = row.expires_at ? new Date(row.expires_at) : null;
    let finalScopes = row.scopes ?? null;

    if (isExpiringSoon && refreshToken) {
      const refreshed = await this.refreshAccessToken(refreshToken);
      if (refreshed?.access_token) {
        finalAccessToken = refreshed.access_token;
        finalScopes = refreshed.scope || finalScopes;
        finalExpiresAt =
          typeof refreshed.expires_in === 'number'
            ? new Date(Date.now() + refreshed.expires_in * 1000)
            : finalExpiresAt;

        await pool.query(
          `UPDATE gitu_google_calendar_connections
           SET encrypted_access_token = $1,
               expires_at = $2,
               scopes = COALESCE($3, scopes),
               updated_at = NOW(),
               last_used_at = NOW()
           WHERE user_id = $4`,
          [encryptSecret(finalAccessToken), finalExpiresAt, finalScopes, userId]
        );
      }
    } else {
      await pool.query(
        `UPDATE gitu_google_calendar_connections
         SET last_used_at = NOW()
         WHERE user_id = $1`,
        [userId]
      );
    }

    return {
      user_id: row.user_id,
      email: row.email ?? null,
      access_token: finalAccessToken,
      refresh_token: refreshToken,
      expires_at: finalExpiresAt,
      scopes: finalScopes,
      created_at: new Date(row.created_at),
      updated_at: new Date(row.updated_at),
      last_used_at: row.last_used_at ? new Date(row.last_used_at) : null,
    };
  }

  async isConnected(userId: string): Promise<boolean> {
    const conn = await this.getConnection(userId);
    return !!conn;
  }

  async disconnect(userId: string): Promise<void> {
    await pool.query(`DELETE FROM gitu_google_calendar_connections WHERE user_id = $1`, [userId]);
  }
}

export const gituGoogleCalendarManager = new GituGoogleCalendarManager();
export default gituGoogleCalendarManager;

