
import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import { authenticateToken } from '../middleware/auth.js';

const router = Router();
router.use(authenticateToken);

router.get('/catalog', async (req: Request, res: Response) => {
    try {
        const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
        const limitRaw = typeof req.query.limit === 'string' ? parseInt(req.query.limit, 10) : 50;
        const offsetRaw = typeof req.query.offset === 'string' ? parseInt(req.query.offset, 10) : 0;

        const limit = Number.isFinite(limitRaw) ? Math.min(Math.max(limitRaw, 1), 200) : 50;
        const offset = Number.isFinite(offsetRaw) ? Math.max(offsetRaw, 0) : 0;

        if (q) {
            const result = await pool.query(
                `SELECT id, slug, name, description, parameters, is_active, created_at, updated_at
                 FROM skill_catalog
                 WHERE is_active = TRUE
                   AND (name ILIKE $1 OR COALESCE(description, '') ILIKE $1)
                 ORDER BY updated_at DESC
                 LIMIT $2 OFFSET $3`,
                [`%${q}%`, limit, offset]
            );
            return res.json({ success: true, catalog: result.rows, limit, offset });
        }

        const result = await pool.query(
            `SELECT id, slug, name, description, parameters, is_active, created_at, updated_at
             FROM skill_catalog
             WHERE is_active = TRUE
             ORDER BY updated_at DESC
             LIMIT $1 OFFSET $2`,
            [limit, offset]
        );
        return res.json({ success: true, catalog: result.rows, limit, offset });
    } catch (error: any) {
        console.error('List catalog skills error:', error);
        return res.status(500).json({ error: error.message });
    }
});

router.post('/install/:catalogId', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).userId;
        const { catalogId } = req.params;
        const nameOverride = typeof req.body?.name === 'string' ? req.body.name.trim() : '';

        const catalogResult = await pool.query(
            `SELECT id, name, description, content, parameters
             FROM skill_catalog
             WHERE id = $1 AND is_active = TRUE`,
            [catalogId]
        );

        if (catalogResult.rows.length === 0) {
            return res.status(404).json({ error: 'Catalog skill not found' });
        }

        const catalogSkill = catalogResult.rows[0];
        const targetName = nameOverride || catalogSkill.name;

        if (!targetName) {
            return res.status(400).json({ error: 'Skill name is required' });
        }

        const existing = await pool.query(
            'SELECT id FROM agent_skills WHERE user_id = $1 AND name = $2',
            [userId, targetName]
        );

        if (existing.rows.length > 0) {
            return res.status(409).json({ error: 'Skill with this name already exists' });
        }

        const id = uuidv4();
        const inserted = await pool.query(
            `INSERT INTO agent_skills (id, user_id, name, description, content, parameters, created_at, updated_at)
             VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
             RETURNING *`,
            [
                id,
                userId,
                targetName,
                catalogSkill.description,
                catalogSkill.content,
                catalogSkill.parameters || '{}',
            ]
        );

        return res.json({ success: true, skill: inserted.rows[0] });
    } catch (error: any) {
        console.error('Install catalog skill error:', error);
        return res.status(500).json({ error: error.message });
    }
});

/**
 * GET /api/agent-skills
 * List all agent skills for the user
 */
router.get('/', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).userId;
        const result = await pool.query(
            'SELECT * FROM agent_skills WHERE user_id = $1 ORDER BY created_at DESC',
            [userId]
        );
        res.json({ success: true, skills: result.rows });
    } catch (error: any) {
        console.error('Get skills error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * GET /api/agent-skills/:id
 * Get a specific skill
 */
router.get('/:id', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).userId;
        const { id } = req.params;
        const result = await pool.query(
            'SELECT * FROM agent_skills WHERE id = $1 AND user_id = $2',
            [id, userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Skill not found' });
        }

        res.json({ success: true, skill: result.rows[0] });
    } catch (error: any) {
        console.error('Get skill error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * POST /api/agent-skills
 * Create a new skill
 */
router.post('/', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).userId;
        const { name, description, content, parameters } = req.body;

        if (!name || !content) {
            return res.status(400).json({ error: 'Name and content are required' });
        }

        // Check if name exists
        const existing = await pool.query(
            'SELECT id FROM agent_skills WHERE user_id = $1 AND name = $2',
            [userId, name]
        );

        if (existing.rows.length > 0) {
            return res.status(400).json({ error: 'Skill with this name already exists' });
        }

        const id = uuidv4();
        const result = await pool.query(
            `INSERT INTO agent_skills (id, user_id, name, description, content, parameters, created_at, updated_at)
       VALUES ($1, $2, $3, $4, $5, $6, NOW(), NOW())
       RETURNING *`,
            [id, userId, name, description, content, parameters || '{}']
        );

        res.json({ success: true, skill: result.rows[0] });
    } catch (error: any) {
        console.error('Create skill error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * PUT /api/agent-skills/:id
 * Update a skill
 */
router.put('/:id', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).userId;
        const { id } = req.params;
        const { name, description, content, parameters, is_active } = req.body;

        const result = await pool.query(
            `UPDATE agent_skills 
       SET name = COALESCE($1, name),
           description = COALESCE($2, description),
           content = COALESCE($3, content),
           parameters = COALESCE($4, parameters),
           is_active = COALESCE($5, is_active),
           updated_at = NOW()
       WHERE id = $6 AND user_id = $7
       RETURNING *`,
            [name, description, content, parameters, is_active, id, userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Skill not found' });
        }

        res.json({ success: true, skill: result.rows[0] });
    } catch (error: any) {
        console.error('Update skill error:', error);
        res.status(500).json({ error: error.message });
    }
});

/**
 * DELETE /api/agent-skills/:id
 * Delete a skill
 */
router.delete('/:id', async (req: Request, res: Response) => {
    try {
        const userId = (req as any).userId;
        const { id } = req.params;

        const result = await pool.query(
            'DELETE FROM agent_skills WHERE id = $1 AND user_id = $2 RETURNING *',
            [id, userId]
        );

        if (result.rows.length === 0) {
            return res.status(404).json({ error: 'Skill not found' });
        }

        res.json({ success: true, deleted: result.rows[0] });
    } catch (error: any) {
        console.error('Delete skill error:', error);
        res.status(500).json({ error: error.message });
    }
});

export default router;
