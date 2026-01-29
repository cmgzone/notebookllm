const DEV_JWT_SECRET = 'your-super-secret-jwt-key-change-in-production';

function isProduction() {
  return process.env.NODE_ENV === 'production';
}

export function getJwtSecret(): string {
  const value = process.env.JWT_SECRET;
  if (value && value.length > 0) return value;
  if (!isProduction()) return DEV_JWT_SECRET;
  throw new Error('JWT_SECRET must be set in production');
}

export function getJwtRefreshSecret(): string {
  const value = process.env.JWT_REFRESH_SECRET;
  if (value && value.length > 0) return value;
  return getJwtSecret();
}

export function getDataEncryptionKey(): string {
  const value =
    process.env.DATA_ENCRYPTION_KEY ||
    process.env.GITHUB_ENCRYPTION_KEY ||
    process.env.JWT_SECRET;
  if (value && value.length > 0) return value;
  if (!isProduction()) return DEV_JWT_SECRET;
  throw new Error('DATA_ENCRYPTION_KEY (or GITHUB_ENCRYPTION_KEY) must be set in production');
}

