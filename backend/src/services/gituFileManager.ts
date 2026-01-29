import path from 'path';
import fs from 'fs/promises';
import pool from '../config/database.js';

const baseDir = path.resolve(process.cwd(), '..');

function resolveSafe(p: string) {
  const target = path.resolve(baseDir, p.replace(/^(\.\/|\.\\)/, ''));
  if (!target.startsWith(baseDir)) {
    throw new Error('Invalid path');
  }
  return target;
}

async function log(userId: string, action: string, p: string, success: boolean, errorMessage?: string) {
  try {
    await pool.query(
      `INSERT INTO file_audit_logs (user_id, action, path, success, error_message) VALUES ($1, $2, $3, $4, $5)`,
      [userId, action, p, success, errorMessage || null]
    );
  } catch {}
}

export async function listDir(userId: string, p: string) {
  const abs = resolveSafe(p);
  try {
    const entries = await fs.readdir(abs, { withFileTypes: true });
    await log(userId, 'list', p, true);
    return entries.map(e => ({
      name: e.name,
      type: e.isDirectory() ? 'dir' : 'file',
    }));
  } catch (e: any) {
    await log(userId, 'list', p, false, e?.message || String(e));
    throw e;
  }
}

export async function readFile(userId: string, p: string) {
  const abs = resolveSafe(p);
  try {
    const data = await fs.readFile(abs, 'utf8');
    await log(userId, 'read', p, true);
    return data;
  } catch (e: any) {
    await log(userId, 'read', p, false, e?.message || String(e));
    throw e;
  }
}

export async function writeFile(userId: string, p: string, content: string) {
  const abs = resolveSafe(p);
  try {
    await fs.mkdir(path.dirname(abs), { recursive: true });
    await fs.writeFile(abs, content, 'utf8');
    await log(userId, 'write', p, true);
    return true;
  } catch (e: any) {
    await log(userId, 'write', p, false, e?.message || String(e));
    throw e;
  }
}
