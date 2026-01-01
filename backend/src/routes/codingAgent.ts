/**
 * Coding Agent Routes
 * API endpoints for code verification and source management
 */

import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import codeVerificationService, { 
  CodeVerificationRequest, 
  VerifiedSource 
} from '../services/codeVerificationService.js';
import { authenticateToken, optionalAuth } from '../middleware/auth.js';

const router = Router();

/**
 * POST /api/coding-agent/verify
 * Verify code for correctness
 */
router.post('/verify', optionalAuth, async (req: Request, res: Response) => {
  try {
    const { code, language, context, strictMode } = req.body;

    if (!code || !language) {
      return res.status(400).json({ 
        error: 'Missing required fields: code, language' 
      });
    }

    const request: CodeVerificationRequest = {
      code,
      language,
      context,
      strictMode: strictMode || false,
    };

    const result = await codeVerificationService.verifyCode(request);

    // Log verification for analytics
    console.log(`[Coding Agent] Verified ${language} code - Score: ${result.score}`);

    res.json({
      success: true,
      verification: result,
    });
  } catch (error: any) {
    console.error('Code verification error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/coding-agent/verify-and-save
 * Verify code and save as source if valid
 */
router.post('/verify-and-save', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { code, language, title, description, notebookId, context, strictMode } = req.body;
    const userId = (req as any).user?.userId;

    if (!code || !language || !title) {
      return res.status(400).json({ 
        error: 'Missing required fields: code, language, title' 
      });
    }

    // Verify the code first
    const verification = await codeVerificationService.verifyCode({
      code,
      language,
      context,
      strictMode: strictMode || false,
    });

    // Only save if code passes verification (score >= 60)
    if (verification.score < 60) {
      return res.status(400).json({
        success: false,
        error: 'Code verification failed',
        verification,
        message: 'Code must have a verification score of at least 60 to be saved as a source',
      });
    }

    // Create verified source
    const sourceId = uuidv4();
    const verifiedSource: VerifiedSource = {
      id: sourceId,
      code,
      language,
      title,
      description: description || `Verified ${language} code`,
      verificationResult: verification,
      createdAt: new Date().toISOString(),
      userId,
      notebookId,
    };

    // Save to database as a source
    const result = await pool.query(
      `INSERT INTO sources (id, notebook_id, user_id, type, title, content, metadata, created_at)
       VALUES ($1, $2, $3, 'code', $4, $5, $6, NOW())
       RETURNING *`,
      [
        sourceId,
        notebookId,
        userId,
        title,
        code,
        JSON.stringify({
          language,
          verification: verification,
          isVerified: true,
          verifiedAt: new Date().toISOString(),
        }),
      ]
    );

    res.json({
      success: true,
      source: result.rows[0],
      verification,
    });
  } catch (error: any) {
    console.error('Verify and save error:', error);
    res.status(500).json({ error: error.message });
  }
});


/**
 * GET /api/coding-agent/sources
 * Get all verified code sources
 */
router.get('/sources', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).user?.userId;
    const { notebookId, language } = req.query;

    let query = `
      SELECT * FROM sources 
      WHERE user_id = $1 
      AND type = 'code'
      AND (metadata->>'isVerified')::boolean = true
    `;
    const params: any[] = [userId];

    if (notebookId) {
      query += ` AND notebook_id = $${params.length + 1}`;
      params.push(notebookId);
    }

    if (language) {
      query += ` AND metadata->>'language' = $${params.length + 1}`;
      params.push(language);
    }

    query += ' ORDER BY created_at DESC';

    const result = await pool.query(query, params);

    res.json({
      success: true,
      sources: result.rows,
      count: result.rows.length,
    });
  } catch (error: any) {
    console.error('Get sources error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/coding-agent/batch-verify
 * Verify multiple code snippets at once
 */
router.post('/batch-verify', optionalAuth, async (req: Request, res: Response) => {
  try {
    const { snippets } = req.body;

    if (!snippets || !Array.isArray(snippets)) {
      return res.status(400).json({ 
        error: 'Missing required field: snippets (array)' 
      });
    }

    const results = await Promise.all(
      snippets.map(async (snippet: any) => {
        const verification = await codeVerificationService.verifyCode({
          code: snippet.code,
          language: snippet.language,
          context: snippet.context,
          strictMode: snippet.strictMode || false,
        });
        return {
          id: snippet.id,
          verification,
        };
      })
    );

    res.json({
      success: true,
      results,
      summary: {
        total: results.length,
        passed: results.filter(r => r.verification.isValid).length,
        failed: results.filter(r => !r.verification.isValid).length,
        averageScore: results.reduce((sum, r) => sum + r.verification.score, 0) / results.length,
      },
    });
  } catch (error: any) {
    console.error('Batch verify error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/coding-agent/analyze
 * Deep analysis of code with suggestions
 */
router.post('/analyze', optionalAuth, async (req: Request, res: Response) => {
  try {
    const { code, language, analysisType } = req.body;

    if (!code || !language) {
      return res.status(400).json({ 
        error: 'Missing required fields: code, language' 
      });
    }

    // Run verification with strict mode for deep analysis
    const verification = await codeVerificationService.verifyCode({
      code,
      language,
      context: `Perform ${analysisType || 'comprehensive'} analysis`,
      strictMode: true,
    });

    res.json({
      success: true,
      analysis: {
        ...verification,
        analysisType: analysisType || 'comprehensive',
      },
    });
  } catch (error: any) {
    console.error('Analysis error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * DELETE /api/coding-agent/sources/:id
 * Delete a verified source
 */
router.delete('/sources/:id', authenticateToken, async (req: Request, res: Response) => {
  try {
    const { id } = req.params;
    const userId = (req as any).user?.userId;

    const result = await pool.query(
      'DELETE FROM sources WHERE id = $1 AND user_id = $2 RETURNING *',
      [id, userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Source not found' });
    }

    res.json({
      success: true,
      deleted: result.rows[0],
    });
  } catch (error: any) {
    console.error('Delete source error:', error);
    res.status(500).json({ error: error.message });
  }
});

export default router;
