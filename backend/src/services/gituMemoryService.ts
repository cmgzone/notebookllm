import pool from '../config/database.js';

export type MemoryCategory = 'personal' | 'work' | 'preference' | 'fact' | 'context';

export interface Memory {
  id: string;
  userId: string;
  category: MemoryCategory;
  content: string;
  source: string;
  confidence: number;
  verified: boolean;
  lastConfirmedByUser?: Date;
  verificationRequired: boolean;
  tags: string[];
  createdAt: Date;
  lastAccessedAt: Date;
  accessCount: number;
}

export interface CreateMemoryOptions {
  category: MemoryCategory;
  content: string;
  source: string;
  confidence?: number;
  tags?: string[];
  verificationRequired?: boolean;
}

export interface UpdateMemoryOptions {
  category?: MemoryCategory;
  content?: string;
  source?: string;
  confidence?: number;
  verified?: boolean;
  lastConfirmedByUser?: Date | null;
  verificationRequired?: boolean;
  tags?: string[];
}

export interface Contradiction {
  id: string;
  memoryId: string;
  contradictsMemoryId: string;
  detectedAt: Date;
  resolved: boolean;
  resolution?: string;
}

class GituMemoryService {
  async createMemory(userId: string, options: CreateMemoryOptions): Promise<Memory> {
    const result = await pool.query(
      `INSERT INTO gitu_memories 
       (user_id, category, content, source, confidence, verified, last_confirmed_by_user, verification_required, tags, created_at, last_accessed_at, access_count)
       VALUES ($1, $2, $3, $4, COALESCE($5, 0.5), false, NULL, COALESCE($6, false), COALESCE($7::text[], '{}'::text[]), NOW(), NOW(), 0)
       RETURNING *`,
      [
        userId,
        options.category,
        options.content,
        options.source,
        options.confidence ?? null,
        options.verificationRequired ?? false,
        options.tags ?? [],
      ]
    );
    const memory = this.mapRowToMemory(result.rows[0]);
    const scored = this.scoreConfidence(memory);
    if (Math.abs(scored - memory.confidence) > 0.0001) {
      await pool.query(`UPDATE gitu_memories SET confidence = $1 WHERE id = $2`, [scored, memory.id]);
      memory.confidence = scored;
    }
    return memory;
  }

  async getMemory(id: string): Promise<Memory | null> {
    const result = await pool.query(`SELECT * FROM gitu_memories WHERE id = $1`, [id]);
    if (result.rows.length === 0) return null;
    const memory = this.mapRowToMemory(result.rows[0]);
    await pool.query(
      `UPDATE gitu_memories SET last_accessed_at = NOW(), access_count = access_count + 1 WHERE id = $1`,
      [id]
    );
    return { ...memory, lastAccessedAt: new Date(), accessCount: memory.accessCount + 1 };
  }

  async listMemories(
    userId: string,
    filters?: { category?: MemoryCategory; verified?: boolean; tags?: string[]; limit?: number; offset?: number }
  ): Promise<Memory[]> {
    const clauses: string[] = ['user_id = $1'];
    const params: any[] = [userId];
    let idx = 2;
    if (filters?.category) {
      clauses.push(`category = $${idx++}`);
      params.push(filters.category);
    }
    if (filters?.verified !== undefined) {
      clauses.push(`verified = $${idx++}`);
      params.push(filters.verified);
    }
    if (filters?.tags && filters.tags.length > 0) {
      clauses.push(`tags && $${idx++}::text[]`);
      params.push(filters.tags);
    }
    const limitOffset =
      filters?.limit || filters?.offset !== undefined
        ? ` LIMIT ${filters?.limit ?? 50} OFFSET ${filters?.offset ?? 0}`
        : '';
    const result = await pool.query(
      `SELECT * FROM gitu_memories WHERE ${clauses.join(' AND ')} ORDER BY last_accessed_at DESC${limitOffset}`,
      params
    );
    return result.rows.map(r => this.mapRowToMemory(r));
  }

  async updateMemory(id: string, updates: UpdateMemoryOptions): Promise<Memory> {
    const existing = await this.getMemory(id);
    if (!existing) throw new Error(`Memory ${id} not found`);
    const fields: string[] = [];
    const values: any[] = [];
    let p = 1;
    if (updates.category !== undefined) {
      fields.push(`category = $${p++}`);
      values.push(updates.category);
    }
    if (updates.content !== undefined) {
      fields.push(`content = $${p++}`);
      values.push(updates.content);
    }
    if (updates.source !== undefined) {
      fields.push(`source = $${p++}`);
      values.push(updates.source);
    }
    if (updates.confidence !== undefined) {
      fields.push(`confidence = $${p++}`);
      values.push(updates.confidence);
    }
    if (updates.verified !== undefined) {
      fields.push(`verified = $${p++}`);
      values.push(updates.verified);
    }
    if (updates.lastConfirmedByUser !== undefined) {
      fields.push(`last_confirmed_by_user = $${p++}`);
      values.push(updates.lastConfirmedByUser);
    }
    if (updates.verificationRequired !== undefined) {
      fields.push(`verification_required = $${p++}`);
      values.push(updates.verificationRequired);
    }
    if (updates.tags !== undefined) {
      fields.push(`tags = $${p++}::text[]`);
      values.push(updates.tags);
    }
    fields.push(`last_accessed_at = NOW()`);
    values.push(id);
    const res = await pool.query(
      `UPDATE gitu_memories SET ${fields.join(', ')} WHERE id = $${p} RETURNING *`,
      values
    );
    const mem = this.mapRowToMemory(res.rows[0]);
    const scored = this.scoreConfidence(mem);
    if (Math.abs(scored - mem.confidence) > 0.0001) {
      await pool.query(`UPDATE gitu_memories SET confidence = $1 WHERE id = $2`, [scored, mem.id]);
      mem.confidence = scored;
    }
    return mem;
  }

  async deleteMemory(id: string): Promise<void> {
    await pool.query(`DELETE FROM gitu_memories WHERE id = $1`, [id]);
  }

  async requestVerification(id: string): Promise<Memory> {
    const res = await pool.query(
      `UPDATE gitu_memories 
       SET verification_required = true, verified = false
       WHERE id = $1
       RETURNING *`,
      [id]
    );
    return this.mapRowToMemory(res.rows[0]);
  }

  async correctMemory(
    id: string,
    updates: { content?: string; category?: MemoryCategory; tags?: string[]; source?: string }
  ): Promise<Memory> {
    const updated = await this.updateMemory(id, {
      content: updates.content,
      category: updates.category,
      tags: updates.tags,
      source: updates.source,
      verified: true,
      verificationRequired: false,
      lastConfirmedByUser: new Date(),
    });
    return updated;
  }

  async expireUnverifiedMemories(days: number = 30): Promise<number> {
    const res = await pool.query(
      `DELETE FROM gitu_memories
       WHERE verified = false
         AND verification_required = true
         AND created_at < NOW() - make_interval(days => $1)
       RETURNING id`,
      [days]
    );
    return res.rowCount || 0;
  }

  async confirmMemory(id: string): Promise<Memory> {
    const res = await pool.query(
      `UPDATE gitu_memories 
       SET verified = true, verification_required = false, last_confirmed_by_user = NOW()
       WHERE id = $1
       RETURNING *`,
      [id]
    );
    const mem = this.mapRowToMemory(res.rows[0]);
    const scored = this.scoreConfidence(mem);
    if (Math.abs(scored - mem.confidence) > 0.0001) {
      await pool.query(`UPDATE gitu_memories SET confidence = $1 WHERE id = $2`, [scored, mem.id]);
      mem.confidence = scored;
    }
    return mem;
  }

  scoreConfidence(memory: Memory): number {
    let score = 0.5;
    if (memory.verified) score += 0.3;
    if (memory.lastConfirmedByUser) {
      const days = (Date.now() - memory.lastConfirmedByUser.getTime()) / (1000 * 60 * 60 * 24);
      if (days <= 30) score += 0.1;
      else if (days > 180) score -= 0.1;
    }
    if (memory.accessCount > 100) score += 0.05;
    score = Math.min(1, Math.max(0, score));
    return parseFloat(score.toFixed(2));
  }

  async detectContradictions(userId: string, category?: MemoryCategory): Promise<number> {
    const clauses: string[] = ['user_id = $1'];
    const params: any[] = [userId];
    let p = 2;
    if (category) {
      clauses.push(`category = $${p++}`);
      params.push(category);
    }
    const result = await pool.query(
      `SELECT id, content FROM gitu_memories WHERE ${clauses.join(' AND ')}`,
      params
    );
    const rows: { id: string; content: string }[] = result.rows;
    const normalize = (s: string) =>
      s
        .toLowerCase()
        .replace(/\b(don't|do not|cannot|can't|no|not)\b/g, '')
        .replace(/\s+/g, ' ')
        .trim();
    const hasNegation = (s: string) => /\b(don't|do not|cannot|can't|no|not)\b/i.test(s);
    let inserted = 0;
    for (let i = 0; i < rows.length; i++) {
      for (let j = i + 1; j < rows.length; j++) {
        const a = rows[i];
        const b = rows[j];
        const na = normalize(a.content);
        const nb = normalize(b.content);
        if (na.length > 0 && na === nb && hasNegation(a.content) !== hasNegation(b.content)) {
          const exists = await pool.query(
            `SELECT id FROM gitu_memory_contradictions 
             WHERE (memory_id = $1 AND contradicts_memory_id = $2) 
                OR (memory_id = $2 AND contradicts_memory_id = $1)`,
            [a.id, b.id]
          );
          if (exists.rows.length === 0) {
            await pool.query(
              `INSERT INTO gitu_memory_contradictions (memory_id, contradicts_memory_id) VALUES ($1, $2)`,
              [a.id, b.id]
            );
            await pool.query(
              `UPDATE gitu_memories SET verification_required = true WHERE id IN ($1, $2)`,
              [a.id, b.id]
            );
            inserted++;
          }
        }
      }
    }
    return inserted;
  }

  async resolveContradiction(contradictionId: string, resolutionText: string): Promise<Contradiction> {
    const res = await pool.query(
      `UPDATE gitu_memory_contradictions 
       SET resolved = true, resolution = $1 
       WHERE id = $2
       RETURNING *`,
      [resolutionText, contradictionId]
    );
    const row = res.rows[0];
    return {
      id: row.id,
      memoryId: row.memory_id,
      contradictsMemoryId: row.contradicts_memory_id,
      detectedAt: new Date(row.detected_at),
      resolved: row.resolved,
      resolution: row.resolution ?? undefined,
    };
  }

  private mapRowToMemory(row: any): Memory {
    return {
      id: row.id,
      userId: row.user_id,
      category: row.category,
      content: row.content,
      source: row.source,
      confidence: typeof row.confidence === 'string' ? parseFloat(row.confidence) : row.confidence,
      verified: row.verified,
      lastConfirmedByUser: row.last_confirmed_by_user ? new Date(row.last_confirmed_by_user) : undefined,
      verificationRequired: row.verification_required,
      tags: row.tags ?? [],
      createdAt: new Date(row.created_at),
      lastAccessedAt: new Date(row.last_accessed_at),
      accessCount: row.access_count,
    };
  }
}

export const gituMemoryService = new GituMemoryService();
export default gituMemoryService;
