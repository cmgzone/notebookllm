import { describe, it, expect, beforeEach, afterEach } from '@jest/globals';
import pool from '../config/database.js';
import gituMemoryService, { MemoryCategory } from '../services/gituMemoryService.js';

describe('GituMemoryService', () => {
  const testUserId = 'test-user-memory-' + Date.now();
  const category: MemoryCategory = 'fact';
  const createdMemoryIds: string[] = [];
  const createdContradictionIds: string[] = [];

  beforeEach(async () => {
    await pool.query(
      `INSERT INTO users (id, email, display_name, password_hash) 
       VALUES ($1, $2, $3, $4) 
       ON CONFLICT (id) DO NOTHING`,
      [testUserId, `test-${testUserId}@example.com`, 'Test User', 'dummy-hash']
    );
  });

  afterEach(async () => {
    try {
      await pool.query(`DELETE FROM gitu_memory_contradictions WHERE memory_id = ANY($1)`, [createdMemoryIds]);
    } catch {}
    try {
      await pool.query(`DELETE FROM gitu_memories WHERE user_id = $1`, [testUserId]);
    } catch {}
    try {
      await pool.query(`DELETE FROM users WHERE id = $1`, [testUserId]);
    } catch {}
    createdMemoryIds.length = 0;
    createdContradictionIds.length = 0;
  });

  it('creates and reads a memory', async () => {
    const mem = await gituMemoryService.createMemory(testUserId, {
      category,
      content: 'Server timezone is UTC',
      source: 'system',
      tags: ['infra'],
    });
    createdMemoryIds.push(mem.id);
    expect(mem.userId).toBe(testUserId);
    expect(mem.category).toBe(category);
    expect(mem.verified).toBe(false);
    const fetched = await gituMemoryService.getMemory(mem.id);
    expect(fetched?.accessCount).toBe(mem.accessCount + 1);
  });

  it('updates memory fields and clamps confidence', async () => {
    const mem = await gituMemoryService.createMemory(testUserId, {
      category,
      content: 'Billing enabled',
      source: 'system',
    });
    createdMemoryIds.push(mem.id);
    const updated = await gituMemoryService.updateMemory(mem.id, {
      verified: true,
      confidence: 0.99,
      tags: ['billing'],
    });
    expect(updated.verified).toBe(true);
    expect(updated.tags).toEqual(['billing']);
    expect(updated.confidence).toBeGreaterThan(0);
    expect(updated.confidence).toBeLessThanOrEqual(1);
  });

  it('lists memories with filters', async () => {
    const m1 = await gituMemoryService.createMemory(testUserId, {
      category: 'preference',
      content: 'Theme is dark',
      source: 'user',
      tags: ['ui'],
    });
    const m2 = await gituMemoryService.createMemory(testUserId, {
      category: 'preference',
      content: 'Font size is large',
      source: 'user',
      tags: ['ui'],
    });
    createdMemoryIds.push(m1.id, m2.id);
    const list = await gituMemoryService.listMemories(testUserId, { category: 'preference', tags: ['ui'] });
    expect(list.length).toBeGreaterThanOrEqual(2);
    expect(list.every(x => x.category === 'preference')).toBe(true);
  });

  it('detects contradictions and marks verification required', async () => {
    const a = await gituMemoryService.createMemory(testUserId, {
      category,
      content: 'Notifications are enabled',
      source: 'user',
    });
    const b = await gituMemoryService.createMemory(testUserId, {
      category,
      content: 'Notifications are not enabled',
      source: 'user',
    });
    createdMemoryIds.push(a.id, b.id);
    const count = await gituMemoryService.detectContradictions(testUserId, category);
    expect(count).toBeGreaterThanOrEqual(1);
    const refreshedA = await gituMemoryService.getMemory(a.id);
    const refreshedB = await gituMemoryService.getMemory(b.id);
    expect(refreshedA?.verificationRequired).toBe(true);
    expect(refreshedB?.verificationRequired).toBe(true);
  });

  it('confirms memory and boosts confidence', async () => {
    const mem = await gituMemoryService.createMemory(testUserId, {
      category,
      content: 'Two-factor is enabled',
      source: 'user',
    });
    createdMemoryIds.push(mem.id);
    const confirmed = await gituMemoryService.confirmMemory(mem.id);
    expect(confirmed.verified).toBe(true);
    expect(confirmed.verificationRequired).toBe(false);
    expect(confirmed.lastConfirmedByUser).toBeInstanceOf(Date);
  });

  it('deletes a memory', async () => {
    const mem = await gituMemoryService.createMemory(testUserId, {
      category,
      content: 'Staging uses Postgres',
      source: 'system',
    });
    createdMemoryIds.push(mem.id);
    await gituMemoryService.deleteMemory(mem.id);
    const fetched = await gituMemoryService.getMemory(mem.id);
    expect(fetched).toBeNull();
  });

  it('requests verification and then confirms memory', async () => {
    const mem = await gituMemoryService.createMemory(testUserId, {
      category,
      content: 'Email notifications are enabled',
      source: 'user',
    });
    createdMemoryIds.push(mem.id);
    const requested = await gituMemoryService.requestVerification(mem.id);
    expect(requested.verificationRequired).toBe(true);
    const confirmed = await gituMemoryService.confirmMemory(mem.id);
    expect(confirmed.verified).toBe(true);
    expect(confirmed.verificationRequired).toBe(false);
  });

  it('expires unverified memories older than threshold', async () => {
    const mem = await gituMemoryService.createMemory(testUserId, {
      category,
      content: 'Old unverified preference',
      source: 'user',
    });
    createdMemoryIds.push(mem.id);
    await pool.query(
      `UPDATE gitu_memories SET verification_required = true, created_at = NOW() - INTERVAL '40 days' WHERE id = $1`,
      [mem.id]
    );
    const deleted = await gituMemoryService.expireUnverifiedMemories(30);
    expect(deleted).toBeGreaterThanOrEqual(1);
    const fetched = await gituMemoryService.getMemory(mem.id);
    expect(fetched).toBeNull();
  });
});
