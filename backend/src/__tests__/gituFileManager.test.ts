import { listDir, readFile, writeFile } from '../services/gituFileManager.js';
import path from 'path';
import fs from 'fs/promises';

const userId = 'file-user';
const tmpDirRel = 'backend/tmp_test_files';
const tmpDirAbs = path.resolve(process.cwd(), '..', 'backend', 'tmp_test_files');

describe('GituFileManager', () => {
  beforeAll(async () => {
    await fs.mkdir(tmpDirAbs, { recursive: true });
  });

  afterAll(async () => {
    try {
      const entries = await fs.readdir(tmpDirAbs);
      for (const name of entries) {
        await fs.unlink(path.join(tmpDirAbs, name)).catch(() => {});
      }
      await fs.rmdir(tmpDirAbs).catch(() => {});
    } catch {}
  });

  test('write and read file', async () => {
    const relPath = path.join('backend', 'tmp_test_files', 'a.txt').replace(/\\/g, '/');
    await writeFile(userId, relPath, 'hello');
    const content = await readFile(userId, relPath);
    expect(content).toBe('hello');
  });

  test('list directory', async () => {
    const entries = await listDir(userId, path.join('backend', 'tmp_test_files').replace(/\\/g, '/'));
    expect(Array.isArray(entries)).toBe(true);
  });

  test('reject path traversal', async () => {
    await expect(readFile(userId, '../../secret.txt')).rejects.toThrow();
  });
});
