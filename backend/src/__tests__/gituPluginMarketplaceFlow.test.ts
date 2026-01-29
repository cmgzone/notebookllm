import request from 'supertest';
import express from 'express';
import jwt from 'jsonwebtoken';
import pool from '../config/database.js';
import gituRoutes from '../routes/gitu.js';

const app = express();
app.use(express.json());
app.use('/api/gitu', gituRoutes);

describe('Gitu Plugin Marketplace - Integration', () => {
  const testUserId = `test-user-plugin-market-${Date.now()}`;
  const testEmail = `test-plugin-market-${Date.now()}@example.com`;
  const jwtSecret = process.env.JWT_SECRET || 'your-super-secret-jwt-key-change-in-production';
  const userAuthToken = jwt.sign({ userId: testUserId }, jwtSecret, { expiresIn: '1h' });

  beforeAll(async () => {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS gitu_plugins (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        user_id TEXT NOT NULL,
        name TEXT NOT NULL,
        description TEXT,
        code TEXT NOT NULL,
        entrypoint TEXT DEFAULT 'run',
        config JSONB DEFAULT '{}',
        source_catalog_id UUID,
        source_catalog_version TEXT,
        enabled BOOLEAN DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_gitu_plugins_user ON gitu_plugins(user_id, updated_at DESC);
      CREATE INDEX IF NOT EXISTS idx_gitu_plugins_enabled ON gitu_plugins(user_id, enabled);
    `);
    await pool.query(`
      ALTER TABLE gitu_plugins ADD COLUMN IF NOT EXISTS config JSONB DEFAULT '{}';
      ALTER TABLE gitu_plugins ADD COLUMN IF NOT EXISTS source_catalog_id UUID;
      ALTER TABLE gitu_plugins ADD COLUMN IF NOT EXISTS source_catalog_version TEXT;
    `);

    await pool.query(`
      CREATE TABLE IF NOT EXISTS gitu_plugin_catalog (
        id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
        slug TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        description TEXT,
        code TEXT NOT NULL,
        entrypoint TEXT DEFAULT 'run',
        version TEXT DEFAULT '1.0.0',
        author TEXT,
        tags JSONB DEFAULT '[]',
        is_active BOOLEAN DEFAULT true,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
      CREATE INDEX IF NOT EXISTS idx_gitu_plugin_catalog_active ON gitu_plugin_catalog(is_active, updated_at DESC);
      CREATE INDEX IF NOT EXISTS idx_gitu_plugin_catalog_updated ON gitu_plugin_catalog(updated_at DESC);
    `);
    await pool.query(`
      ALTER TABLE gitu_plugin_catalog ADD COLUMN IF NOT EXISTS slug TEXT;
      ALTER TABLE gitu_plugin_catalog ADD COLUMN IF NOT EXISTS name TEXT;
      ALTER TABLE gitu_plugin_catalog ADD COLUMN IF NOT EXISTS description TEXT;
      ALTER TABLE gitu_plugin_catalog ADD COLUMN IF NOT EXISTS code TEXT;
      ALTER TABLE gitu_plugin_catalog ADD COLUMN IF NOT EXISTS entrypoint TEXT DEFAULT 'run';
      ALTER TABLE gitu_plugin_catalog ADD COLUMN IF NOT EXISTS version TEXT DEFAULT '1.0.0';
      ALTER TABLE gitu_plugin_catalog ADD COLUMN IF NOT EXISTS author TEXT;
      ALTER TABLE gitu_plugin_catalog ADD COLUMN IF NOT EXISTS tags JSONB DEFAULT '[]';
      ALTER TABLE gitu_plugin_catalog ADD COLUMN IF NOT EXISTS is_active BOOLEAN DEFAULT true;
    `);

    await pool.query(
      `INSERT INTO users (id, email, password_hash, display_name) 
       VALUES ($1, $2, 'test-hash', 'Test User')
       ON CONFLICT (id) DO NOTHING`,
      [testUserId, testEmail]
    );
  });

  afterAll(async () => {
    try {
      await pool.query('DELETE FROM gitu_plugins WHERE user_id = $1', [testUserId]);
    } catch {}
    try {
      await pool.query('DELETE FROM gitu_plugin_catalog WHERE slug LIKE $1', [`test-%`]);
    } catch {}
    try {
      await pool.query('DELETE FROM users WHERE id = $1', [testUserId]);
    } catch {}
  });

  it('lists catalog and installs a plugin from catalog', async () => {
    const inserted = await pool.query(
      `INSERT INTO gitu_plugin_catalog (slug, name, description, code, entrypoint, version, author, tags, is_active, created_at, updated_at)
       VALUES ($1,$2,$3,$4,$5,$6,$7,$8,true,NOW(),NOW())
       RETURNING id`,
      [
        `test-echo-${Date.now()}`,
        'Echo Plugin',
        'Returns input',
        `module.exports = async (ctx) => ({ ok: true, input: ctx.input, config: ctx.config });`,
        'run',
        '1.0.0',
        'Notebook',
        JSON.stringify(['test']),
      ]
    );
    const catalogId = inserted.rows[0].id as string;

    const list = await request(app)
      .get('/api/gitu/plugins/catalog')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .query({ tag: 'test' });
    if (list.status !== 200) {
      throw new Error(`catalog list failed: ${list.status} ${JSON.stringify(list.body)}`);
    }
    expect((list.body.catalog as any[]).some(i => i.id === catalogId)).toBe(true);

    const install = await request(app)
      .post(`/api/gitu/plugins/catalog/${catalogId}/install`)
      .set('Authorization', `Bearer ${userAuthToken}`)
      .send({ config: { foo: 'bar' }, enabled: true })
      .expect(201);
    expect(install.body.plugin.id).toBeTruthy();
    expect(install.body.plugin.sourceCatalogId).toBe(catalogId);

    const plugins = await request(app)
      .get('/api/gitu/plugins')
      .set('Authorization', `Bearer ${userAuthToken}`)
      .expect(200);
    expect((plugins.body.plugins as any[]).some(p => p.id === install.body.plugin.id)).toBe(true);
  });
});
