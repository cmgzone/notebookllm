/**
 * Coding Agent Routes
 * API endpoints for code verification, source management, and agent communication
 * 
 * Requirements: 1.1, 1.2, 1.3, 2.1, 2.2, 2.3, 3.2, 3.3, 5.1
 */

import { Router, Request, Response } from 'express';
import { v4 as uuidv4 } from 'uuid';
import pool from '../config/database.js';
import codeVerificationService, { 
  CodeVerificationRequest, 
  VerifiedSource 
} from '../services/codeVerificationService.js';
import { authenticateToken, optionalAuth } from '../middleware/auth.js';
import { agentSessionService } from '../services/agentSessionService.js';
import { agentNotebookService } from '../services/agentNotebookService.js';
import { sourceConversationService } from '../services/sourceConversationService.js';
import { webhookService } from '../services/webhookService.js';
import { agentWebSocketService } from '../services/agentWebSocketService.js';

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
    const userId = (req as any).userId;

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
    const userId = (req as any).userId;
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
    const userId = (req as any).userId;

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

// ==================== AGENT COMMUNICATION ENDPOINTS ====================

/**
 * POST /api/coding-agent/notebooks
 * Create or get an agent notebook (idempotent)
 * 
 * Requirements: 1.1, 1.2, 1.3
 */
router.post('/notebooks', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { 
      agentName, 
      agentIdentifier, 
      webhookUrl, 
      webhookSecret,
      title,
      description,
      metadata = {}
    } = req.body;

    // Validate required fields
    if (!agentName || !agentIdentifier) {
      return res.status(400).json({ 
        error: 'Missing required fields: agentName, agentIdentifier' 
      });
    }

    // Create or get agent session (idempotent - Requirement 1.3)
    const session = await agentSessionService.createSession(userId, {
      agentName,
      agentIdentifier,
      webhookUrl,
      webhookSecret,
      metadata,
    });

    // Create or get notebook for this session (idempotent - Requirement 1.3)
    const notebook = await agentNotebookService.createOrGetNotebook(
      userId,
      session,
      { title, description }
    );

    console.log(`[Coding Agent] Notebook created/retrieved for ${agentName}: ${notebook.id}`);

    res.json({
      success: true,
      notebook: {
        id: notebook.id,
        title: notebook.title,
        description: notebook.description,
        isAgentNotebook: notebook.isAgentNotebook,
        createdAt: notebook.createdAt,
      },
      session: {
        id: session.id,
        agentName: session.agentName,
        agentIdentifier: session.agentIdentifier,
        status: session.status,
      },
    });
  } catch (error: any) {
    console.error('Create agent notebook error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/coding-agent/sources/with-context
 * Save a verified source with conversation context
 * 
 * Requirements: 2.1, 2.2, 2.3
 */
router.post('/sources/with-context', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { 
      code, 
      language, 
      title, 
      description,
      notebookId,
      agentSessionId,
      conversationContext,
      verification,
      strictMode = false
    } = req.body;

    // Validate required fields
    if (!code || !language || !title || !notebookId) {
      return res.status(400).json({ 
        error: 'Missing required fields: code, language, title, notebookId' 
      });
    }

    // Verify the notebook belongs to the user and is an agent notebook
    const notebookResult = await pool.query(
      `SELECT * FROM notebooks WHERE id = $1 AND user_id = $2`,
      [notebookId, userId]
    );

    if (notebookResult.rows.length === 0) {
      return res.status(404).json({ error: 'Notebook not found' });
    }

    // Get agent session info if provided
    let agentName = 'Unknown Agent';
    let sessionId = agentSessionId;
    
    if (agentSessionId) {
      const session = await agentSessionService.getSession(agentSessionId);
      if (session) {
        agentName = session.agentName;
        // Update session activity
        await agentSessionService.updateActivity(agentSessionId);
      }
    } else if (notebookResult.rows[0].agent_session_id) {
      // Use notebook's agent session if not provided
      sessionId = notebookResult.rows[0].agent_session_id;
      const session = await agentSessionService.getSession(sessionId);
      if (session) {
        agentName = session.agentName;
      }
    }

    // Verify the code if verification not provided
    let verificationResult = verification;
    if (!verificationResult) {
      verificationResult = await codeVerificationService.verifyCode({
        code,
        language,
        context: conversationContext,
        strictMode,
      });
    }

    // Create the source with agent context (Requirements 2.1, 2.2, 2.3)
    const sourceId = uuidv4();
    const sourceMetadata = {
      language,
      verification: verificationResult,
      isVerified: verificationResult?.isValid ?? true,
      verifiedAt: new Date().toISOString(),
      agentSessionId: sessionId,
      agentName,
      originalContext: conversationContext,  // Requirement 2.3
    };

    const result = await pool.query(
      `INSERT INTO sources (id, notebook_id, user_id, type, title, content, metadata, created_at)
       VALUES ($1, $2, $3, 'code', $4, $5, $6, NOW())
       RETURNING *`,
      [sourceId, notebookId, userId, title, code, JSON.stringify(sourceMetadata)]
    );

    // Create a conversation for this source if context was provided
    if (conversationContext) {
      await sourceConversationService.getOrCreateConversation(sourceId, sessionId);
    }

    console.log(`[Coding Agent] Source saved with context: ${sourceId} by ${agentName}`);

    res.json({
      success: true,
      source: {
        id: result.rows[0].id,
        notebookId: result.rows[0].notebook_id,
        title: result.rows[0].title,
        type: result.rows[0].type,
        metadata: sourceMetadata,
        createdAt: result.rows[0].created_at,
      },
      verification: verificationResult,
    });
  } catch (error: any) {
    console.error('Save source with context error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/coding-agent/followups
 * Get pending user messages for an agent
 * 
 * Requirements: 3.2
 */
router.get('/followups', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { agentSessionId, agentIdentifier } = req.query;

    // Get the agent session
    let session;
    if (agentSessionId) {
      session = await agentSessionService.getSession(agentSessionId as string);
    } else if (agentIdentifier) {
      session = await agentSessionService.getSessionByAgent(userId, agentIdentifier as string);
    }

    if (!session) {
      return res.status(404).json({ error: 'Agent session not found' });
    }

    // Verify the session belongs to the user
    if (session.userId !== userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Get pending messages for this agent session
    const pendingMessages = await sourceConversationService.getPendingUserMessages(session.id);

    // Enrich messages with source info
    const enrichedMessages = await Promise.all(
      pendingMessages.map(async (msg) => {
        const sourceResult = await pool.query(
          `SELECT title, content, metadata FROM sources WHERE id = $1`,
          [msg.sourceId]
        );
        const source = sourceResult.rows[0];
        return {
          ...msg,
          sourceTitle: source?.title || 'Unknown',
          sourceCode: source?.content || '',
          sourceLanguage: source?.metadata?.language || 'unknown',
        };
      })
    );

    res.json({
      success: true,
      messages: enrichedMessages,
      count: enrichedMessages.length,
      session: {
        id: session.id,
        agentName: session.agentName,
        status: session.status,
      },
    });
  } catch (error: any) {
    console.error('Get followups error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/coding-agent/followups/:id/respond
 * Agent responds to a user message
 * 
 * Requirements: 3.3
 */
router.post('/followups/:id/respond', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { id: messageId } = req.params;
    const { response, codeUpdate, agentSessionId } = req.body;

    if (!response) {
      return res.status(400).json({ error: 'Missing required field: response' });
    }

    // Get the original message to find the source
    const messageResult = await pool.query(
      `SELECT cm.*, sc.source_id, sc.agent_session_id
       FROM conversation_messages cm
       JOIN source_conversations sc ON cm.conversation_id = sc.id
       WHERE cm.id = $1`,
      [messageId]
    );

    if (messageResult.rows.length === 0) {
      return res.status(404).json({ error: 'Message not found' });
    }

    const originalMessage = messageResult.rows[0];
    const sourceId = originalMessage.source_id;
    const sessionId = agentSessionId || originalMessage.agent_session_id;

    // Verify the session belongs to the user
    if (sessionId) {
      const session = await agentSessionService.getSession(sessionId);
      if (session && session.userId !== userId) {
        return res.status(403).json({ error: 'Access denied' });
      }
    }

    // Add the agent's response to the conversation
    const agentMessage = await sourceConversationService.addMessage(
      sourceId,
      'agent',
      response,
      {
        metadata: {
          codeUpdate,
          inReplyTo: messageId,
        },
      }
    );

    // Mark the original message as read
    await sourceConversationService.markMessagesAsRead([messageId]);

    // If there's a code update, update the source
    if (codeUpdate?.code) {
      await pool.query(
        `UPDATE sources 
         SET content = $1, 
             metadata = jsonb_set(
               COALESCE(metadata, '{}')::jsonb, 
               '{lastCodeUpdate}', 
               $2::jsonb
             ),
             updated_at = NOW()
         WHERE id = $3`,
        [
          codeUpdate.code,
          JSON.stringify({
            description: codeUpdate.description,
            updatedAt: new Date().toISOString(),
          }),
          sourceId,
        ]
      );
    }

    console.log(`[Coding Agent] Agent responded to message ${messageId}`);

    res.json({
      success: true,
      message: agentMessage,
      codeUpdated: !!codeUpdate?.code,
    });
  } catch (error: any) {
    console.error('Respond to followup error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/coding-agent/webhook/register
 * Register a webhook endpoint for an agent session
 * 
 * Requirements: 5.1
 */
router.post('/webhook/register', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { agentSessionId, agentIdentifier, webhookUrl, webhookSecret } = req.body;

    // Validate required fields
    if (!webhookUrl || !webhookSecret) {
      return res.status(400).json({ 
        error: 'Missing required fields: webhookUrl, webhookSecret' 
      });
    }

    // Get the agent session
    let session;
    if (agentSessionId) {
      session = await agentSessionService.getSession(agentSessionId);
    } else if (agentIdentifier) {
      session = await agentSessionService.getSessionByAgent(userId, agentIdentifier);
    }

    if (!session) {
      return res.status(404).json({ error: 'Agent session not found' });
    }

    // Verify the session belongs to the user
    if (session.userId !== userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Register the webhook
    await webhookService.registerWebhook(session.id, webhookUrl, webhookSecret);

    console.log(`[Coding Agent] Webhook registered for session ${session.id}`);

    res.json({
      success: true,
      message: 'Webhook registered successfully',
      session: {
        id: session.id,
        agentName: session.agentName,
        webhookConfigured: true,
      },
    });
  } catch (error: any) {
    console.error('Register webhook error:', error);
    
    // Handle specific validation errors
    if (error.message.includes('Invalid webhook URL') || 
        error.message.includes('Webhook secret must be')) {
      return res.status(400).json({ error: error.message });
    }
    
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/coding-agent/followups/send
 * User sends a follow-up message to an agent (routes via WebSocket or webhook)
 * 
 * Requirements: 3.2
 */
router.post('/followups/send', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { sourceId, message } = req.body;

    if (!sourceId || !message) {
      return res.status(400).json({ 
        error: 'Missing required fields: sourceId, message' 
      });
    }

    // Get the source and verify ownership
    const sourceResult = await pool.query(
      `SELECT s.*, n.agent_session_id 
       FROM sources s
       LEFT JOIN notebooks n ON s.notebook_id = n.id
       WHERE s.id = $1 AND s.user_id = $2`,
      [sourceId, userId]
    );

    if (sourceResult.rows.length === 0) {
      return res.status(404).json({ error: 'Source not found' });
    }

    const source = sourceResult.rows[0];
    const metadata = typeof source.metadata === 'string' 
      ? JSON.parse(source.metadata) 
      : (source.metadata || {});
    const agentSessionId = metadata.agentSessionId || source.agent_session_id;

    if (!agentSessionId) {
      return res.status(400).json({ error: 'Source is not associated with an agent session' });
    }

    // Add the user's message to the conversation
    const userMessage = await sourceConversationService.addMessage(
      sourceId,
      'user',
      message
    );

    // Get conversation history
    const conversation = await sourceConversationService.getConversation(sourceId);
    const conversationHistory = conversation?.messages || [];

    // Build payload
    const payload = {
      sourceId,
      sourceTitle: source.title || 'Untitled',
      sourceCode: source.content || '',
      sourceLanguage: metadata.language || 'unknown',
      message,
      messageId: userMessage.id,
      conversationHistory,
      userId,
      timestamp: new Date().toISOString(),
    };

    let delivered = false;
    let deliveryMethod = 'none';
    let agentResponse: string | null = null;

    // Try WebSocket first (instant delivery)
    if (agentWebSocketService.isAgentConnected(agentSessionId)) {
      delivered = await agentWebSocketService.sendFollowupToAgent(agentSessionId, payload);
      if (delivered) {
        deliveryMethod = 'websocket';
        console.log(`[Coding Agent] Message sent via WebSocket to session ${agentSessionId}`);
      }
    }

    // Fall back to webhook if WebSocket not available
    if (!delivered) {
      const webhookPayload = await webhookService.buildPayload(
        sourceId,
        message,
        conversationHistory,
        userId
      );

      const webhookResponse = await webhookService.sendFollowup(agentSessionId, webhookPayload);

      if (webhookResponse.success) {
        delivered = true;
        deliveryMethod = 'webhook';
        agentResponse = webhookResponse.response || null;

        // If webhook returned a response, add it to the conversation
        if (webhookResponse.response) {
          await sourceConversationService.addMessage(
            sourceId,
            'agent',
            webhookResponse.response,
            {
              metadata: {
                codeUpdate: webhookResponse.codeUpdate,
                deliveredViaWebhook: true,
              },
            }
          );

          // Update source code if there's a code update
          if (webhookResponse.codeUpdate?.code) {
            await pool.query(
              `UPDATE sources 
               SET content = $1, 
                   metadata = jsonb_set(
                     COALESCE(metadata, '{}')::jsonb, 
                     '{lastCodeUpdate}', 
                     $2::jsonb
                   ),
                   updated_at = NOW()
               WHERE id = $3`,
              [
                webhookResponse.codeUpdate.code,
                JSON.stringify({
                  description: webhookResponse.codeUpdate.description,
                  updatedAt: new Date().toISOString(),
                }),
                sourceId,
              ]
            );
          }
        }
      }
    }

    console.log(`[Coding Agent] User sent followup for source ${sourceId} (delivery: ${deliveryMethod})`);

    res.json({
      success: true,
      message: userMessage,
      delivered,
      deliveryMethod,
      agentResponse,
      note: deliveryMethod === 'websocket' 
        ? 'Message sent to agent via WebSocket. Response will appear when agent replies.'
        : deliveryMethod === 'webhook'
        ? 'Message delivered via webhook.'
        : 'Message stored. Agent will see it when they poll for messages.',
    });
  } catch (error: any) {
    console.error('Send followup error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/coding-agent/notebooks
 * Get all agent notebooks for the current user
 * 
 * Requirements: 4.1
 */
router.get('/notebooks', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;

    // Get all agent notebooks for this user
    const notebooks = await agentNotebookService.getAgentNotebooks(userId);

    // Enrich with session info
    const enrichedNotebooks = await Promise.all(
      notebooks.map(async (notebook) => {
        let sessionInfo: {
          id: string;
          agentName: string;
          agentIdentifier: string;
          status: 'active' | 'expired' | 'disconnected';
          lastActivity: Date;
        } | null = null;
        if (notebook.agentSessionId) {
          const session = await agentSessionService.getSession(notebook.agentSessionId);
          if (session) {
            sessionInfo = {
              id: session.id,
              agentName: session.agentName,
              agentIdentifier: session.agentIdentifier,
              status: session.status,
              lastActivity: session.lastActivity,
            };
          }
        }
        return {
          ...notebook,
          session: sessionInfo,
        };
      })
    );

    res.json({
      success: true,
      notebooks: enrichedNotebooks,
      count: enrichedNotebooks.length,
    });
  } catch (error: any) {
    console.error('Get agent notebooks error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * POST /api/coding-agent/sessions/:sessionId/disconnect
 * Disconnect an agent session
 * 
 * Requirements: 4.3
 */
router.post('/sessions/:sessionId/disconnect', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { sessionId } = req.params;

    // Get the session and verify ownership
    const session = await agentSessionService.getSession(sessionId);
    
    if (!session) {
      return res.status(404).json({ error: 'Session not found' });
    }

    if (session.userId !== userId) {
      return res.status(403).json({ error: 'Access denied' });
    }

    // Disconnect the session
    await agentSessionService.disconnectSession(sessionId);

    console.log(`[Coding Agent] Session ${sessionId} disconnected by user ${userId}`);

    res.json({
      success: true,
      message: 'Agent session disconnected',
      session: {
        id: sessionId,
        status: 'disconnected',
      },
    });
  } catch (error: any) {
    console.error('Disconnect session error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/coding-agent/conversations/:sourceId
 * Get conversation history for a source
 * 
 * Requirements: 3.5
 */
router.get('/conversations/:sourceId', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;
    const { sourceId } = req.params;

    // Verify source ownership
    const sourceResult = await pool.query(
      `SELECT id FROM sources WHERE id = $1 AND user_id = $2`,
      [sourceId, userId]
    );

    if (sourceResult.rows.length === 0) {
      return res.status(404).json({ error: 'Source not found' });
    }

    // Get conversation
    const conversation = await sourceConversationService.getConversation(sourceId);

    if (!conversation) {
      return res.json({
        success: true,
        conversation: null,
        messages: [],
      });
    }

    res.json({
      success: true,
      conversation: {
        id: conversation.id,
        sourceId: conversation.sourceId,
        agentSessionId: conversation.agentSessionId,
        createdAt: conversation.createdAt,
        lastMessageAt: conversation.lastMessageAt,
      },
      messages: conversation.messages,
    });
  } catch (error: any) {
    console.error('Get conversation error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/coding-agent/websocket/status
 * Get WebSocket connection status for agent sessions
 */
router.get('/websocket/status', authenticateToken, async (req: Request, res: Response) => {
  try {
    const userId = (req as any).userId;

    // Get all agent sessions for this user
    const sessionsResult = await pool.query(
      `SELECT id, agent_name, agent_identifier, status FROM agent_sessions WHERE user_id = $1`,
      [userId]
    );

    const sessions = sessionsResult.rows.map(session => ({
      id: session.id,
      agentName: session.agent_name,
      agentIdentifier: session.agent_identifier,
      status: session.status,
      websocketConnected: agentWebSocketService.isAgentConnected(session.id),
    }));

    const stats = agentWebSocketService.getStats();

    res.json({
      success: true,
      sessions,
      stats,
      websocketUrl: `wss://${req.get('host')}/ws/agent`,
    });
  } catch (error: any) {
    console.error('WebSocket status error:', error);
    res.status(500).json({ error: error.message });
  }
});

/**
 * GET /api/coding-agent/websocket/info
 * Get WebSocket connection info for agents
 */
router.get('/websocket/info', optionalAuth, async (req: Request, res: Response) => {
  const backendUrl = process.env.BACKEND_URL || `${req.protocol}://${req.get('host')}`;
  const wsUrl = backendUrl.replace('https://', 'wss://').replace('http://', 'ws://');

  res.json({
    success: true,
    websocket: {
      url: `${wsUrl}/ws/agent`,
      protocol: 'wss',
      authentication: 'Query parameter: ?token=YOUR_API_TOKEN&sessionId=YOUR_SESSION_ID',
      messageTypes: {
        incoming: ['followup_message', 'ping'],
        outgoing: ['response', 'pong'],
      },
    },
    example: {
      connect: `const ws = new WebSocket('${wsUrl}/ws/agent?token=nllm_xxx&sessionId=xxx')`,
      sendResponse: JSON.stringify({
        type: 'response',
        messageId: 'message-uuid',
        payload: {
          response: 'Your response text',
          codeUpdate: { code: '...', description: '...' },
        },
      }),
    },
  });
});

export default router;
