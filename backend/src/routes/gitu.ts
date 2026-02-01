/**
 * Gitu Core Routes
 * API endpoints for Gitu core features (Scheduled Tasks, etc.)
 * 
 * Requirements: Task 2.3.3
 */

import express, { type Response } from 'express';
import pool from '../config/database.js';
import { authenticateToken, type AuthRequest } from '../middleware/auth.js';
import { gituScheduler } from '../services/gituScheduler.js';
import { v4 as uuidv4 } from 'uuid';
import { gituIdentityManager } from '../services/gituIdentityManager.js';
import { listDir, readFile, writeFile } from '../services/gituFileManager.js';
import { gituPermissionManager } from '../services/gituPermissionManager.js';
import { gituShellManager } from '../services/gituShellManager.js';
import { gituRuleEngine } from '../services/gituRuleEngine.js';
import { gituPluginSystem } from '../services/gituPluginSystem.js';
import { gituTerminalService } from '../services/gituTerminalService.js';
import { gituRemoteTerminalService } from '../services/gituRemoteTerminalService.js';
import { gituGmailManager } from '../services/gituGmailManager.js';
import { gituShopifyManager } from '../services/gituShopifyManager.js';
import { gituAgentManager } from '../services/gituAgentManager.js';
import { gituMemoryService } from '../services/gituMemoryService.js';
import { gituProactiveService } from '../services/gituProactiveService.js';
import { whatsappAdapter } from '../adapters/whatsappAdapter.js';
import {
  listMessages as gmailList,
  getMessage as gmailGet,
  sendEmail as gmailSend,
  listLabels as gmailLabels,
  modifyMessageLabels as gmailModifyLabels,
} from '../services/gituGmailOperations.js';
import {
  summarizeEmail,
  suggestReplies,
  extractActionItems,
  analyzeSentiment,
} from '../services/gituGmailAI.js';
import { gituAIRouter } from '../services/gituAIRouter.js';
import { generateEmbedding } from '../services/aiService.js';
import { gituMissionControl } from '../services/gituMissionControl.js';
import { gituSelfImprovementService } from '../services/gituSelfImprovementService.js';

const router = express.Router();
const normalizeScopePath = (p: string) =>
  p
    .trim()
    .replace(/^(\.\/|\.\\)+/, '')
    .replace(/\\/g, '/')
    .replace(/\/+/g, '/')
    .replace(/\/$/, '');

router.post('/message', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const { message, context, sessionId } = req.body;
    if (!message || typeof message !== 'string') {
      return res.status(400).json({ error: 'message is required' });
    }

    // Route through GituAIRouter
    const response = await gituAIRouter.route({
      userId: req.userId!,
      platform: 'cli',
      platformUserId: 'cli-user',
      sessionId,
      content: message,
      taskType: 'chat',
      useRetrieval: true // Enable RAG by default for CLI
    });

    res.json({ success: true, content: response.content });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to process message', message: error.message });
  }
});

router.post('/terminal/link', async (req: AuthRequest, res: Response) => {
  try {
    const { token, deviceId, deviceName } = req.body as any;
    if (!token || typeof token !== 'string') {
      return res.status(400).json({ error: 'token is required' });
    }
    if (!deviceId || typeof deviceId !== 'string') {
      return res.status(400).json({ error: 'deviceId is required' });
    }
    const result = await gituTerminalService.linkTerminal(token, deviceId, deviceName);
    res.json({
      authToken: result.authToken,
      userId: result.userId,
      expiresAt: result.expiresAt.toISOString(),
      expiresInDays: result.expiresInDays,
    });
  } catch (error: any) {
    const msg = String(error?.message || '');
    const status = msg.toLowerCase().includes('invalid') || msg.toLowerCase().includes('expired') ? 401 : 500;
    res.status(status).json({ error: msg || 'Failed to link terminal' });
  }
});

router.post('/terminal/validate', async (req: AuthRequest, res: Response) => {
  try {
    const { authToken } = req.body as any;
    if (!authToken || typeof authToken !== 'string') {
      return res.status(400).json({ error: 'authToken is required' });
    }
    const result = await gituTerminalService.validateAuthToken(authToken);
    res.json({
      valid: result.valid,
      userId: result.userId,
      deviceId: result.deviceId,
      expiresAt: result.expiresAt ? result.expiresAt.toISOString() : undefined,
      error: result.error,
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to validate terminal token', message: error.message });
  }
});

router.post('/terminal/refresh', async (req: AuthRequest, res: Response) => {
  try {
    const { authToken } = req.body as any;
    if (!authToken || typeof authToken !== 'string') {
      return res.status(400).json({ error: 'authToken is required' });
    }
    const result = await gituTerminalService.refreshAuthToken(authToken);
    res.json({
      authToken: result.authToken,
      expiresAt: result.expiresAt.toISOString(),
      expiresInDays: result.expiresInDays,
    });
  } catch (error: any) {
    const msg = String(error?.message || '');
    const status = msg.toLowerCase().includes('not') || msg.toLowerCase().includes('invalid') ? 401 : 500;
    res.status(status).json({ error: msg || 'Failed to refresh terminal token' });
  }
});

router.post('/terminal/generate-token', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const result = await gituTerminalService.generatePairingToken(req.userId!);
    res.json({
      token: result.code,
      expiresAt: result.expiresAt.toISOString(),
      expiresInSeconds: result.expiresInSeconds,
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to generate pairing token', message: error.message });
  }
});

router.get('/terminal/devices', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const devices = await gituTerminalService.listLinkedDevices(req.userId!);
    res.json({ success: true, devices });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list linked devices', message: error.message });
  }
});

router.post('/terminal/unlink', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const { deviceId } = req.body as any;
    if (!deviceId || typeof deviceId !== 'string') {
      return res.status(400).json({ error: 'deviceId is required' });
    }
    await gituTerminalService.unlinkTerminal(req.userId!, deviceId);
    gituRemoteTerminalService.disconnectDevice(req.userId!, deviceId);
    res.json({ success: true, message: 'Device unlinked successfully' });
  } catch (error: any) {
    if (String(error?.message || '').toLowerCase().includes('not found')) {
      return res.status(404).json({ error: 'Device not found' });
    }
    res.status(500).json({ error: 'Failed to unlink device', message: error.message });
  }
});

router.post('/terminal/source', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const { code, filename, notebookId } = req.body as any;
    if (!code || typeof code !== 'string') {
      return res.status(400).json({ error: 'code is required' });
    }
    const name = filename || 'CLI Upload';

    // Find or use provided notebook
    let targetNotebookId = notebookId;
    if (!targetNotebookId) {
      // Try to find a recent notebook or default
      const result = await pool.query(
        `SELECT id FROM notebooks WHERE user_id = $1 ORDER BY updated_at DESC LIMIT 1`,
        [req.userId]
      );
      if (result.rows.length > 0) {
        targetNotebookId = result.rows[0].id;
      } else {
        // Create default notebook
        const newNb = await pool.query(
          `INSERT INTO notebooks (user_id, title, description) VALUES ($1, 'CLI Uploads', 'Auto-generated for CLI') RETURNING id`,
          [req.userId]
        );
        targetNotebookId = newNb.rows[0].id;
      }
    }

    // Insert Source
    const sourceId = uuidv4();
    await pool.query(
      `INSERT INTO sources (id, notebook_id, title, type, content, created_at)
         VALUES ($1, $2, $3, 'text', $4, NOW())`,
      [sourceId, targetNotebookId, name, code]
    );

    // Chunking & Embedding
    const chunkSize = 1000;
    const overlap = 100;
    const chunks: string[] = [];

    for (let i = 0; i < code.length; i += (chunkSize - overlap)) {
      chunks.push(code.substring(i, i + chunkSize));
    }

    // Process chunks
    for (let i = 0; i < chunks.length; i++) {
      const chunkText = chunks[i];
      try {
        const embedding = await generateEmbedding(chunkText);
        const vectorStr = `[${embedding.join(',')}]`;

        await pool.query(
          `INSERT INTO chunks (id, source_id, content_text, chunk_index, embedding)
                 VALUES ($1, $2, $3, $4, $5)`,
          [uuidv4(), sourceId, chunkText, i, vectorStr]
        );
      } catch (e) {
        console.error(`Failed to embed chunk ${i}:`, e);
        // Insert without embedding as fallback
        await pool.query(
          `INSERT INTO chunks (id, source_id, content_text, chunk_index)
                 VALUES ($1, $2, $3, $4)`,
          [uuidv4(), sourceId, chunkText, i]
        );
      }
    }

    res.json({ success: true, sourceId, notebookId: targetNotebookId, chunks: chunks.length });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to upload source', message: error.message });
  }
});

router.use(authenticateToken);

router.get('/settings', async (req: AuthRequest, res: Response) => {
  try {
    const prefs = await gituAIRouter.getUserPreferences(req.userId!);
    const result = await pool.query(
      `SELECT gitu_settings FROM users WHERE id = $1`,
      [req.userId]
    );
    const raw = result.rows[0]?.gitu_settings || {};
    const enabled = !!raw.enabled;
    res.json({
      enabled,
      settings: { modelPreferences: prefs },
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to load settings', message: error.message });
  }
});

router.post('/settings', async (req: AuthRequest, res: Response) => {
  try {
    const body = req.body as any;
    const enabled = body?.enabled === true;
    const modelPrefs = body?.settings?.modelPreferences;

    if (modelPrefs && typeof modelPrefs === 'object') {
      await gituAIRouter.updateUserPreferences(req.userId!, modelPrefs);
    }

    await pool.query(
      `UPDATE users 
       SET gitu_settings = jsonb_set(
         COALESCE(gitu_settings, '{}'::jsonb),
         '{enabled}',
         to_jsonb($1::boolean),
         true
       )
       WHERE id = $2`,
      [enabled, req.userId]
    );

    const prefs = await gituAIRouter.getUserPreferences(req.userId!);
    res.json({
      enabled,
      settings: { modelPreferences: prefs },
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to update settings', message: error.message });
  }
});

router.get('/whatsapp/status', async (req: AuthRequest, res: Response) => {
  try {
    const state = whatsappAdapter.getConnectionState();
    const qr = whatsappAdapter.getQRCode();
    const account = whatsappAdapter.getConnectedAccount();
    const status =
      state === 'connected'
        ? 'connected'
        : qr
          ? 'scanning'
          : 'disconnected';
    res.json({
      success: true,
      status,
      qrCode: qr,
      device: account?.name || null,
      platformUserId: account?.jid || null,
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get WhatsApp status', message: error.message });
  }
});

router.post('/whatsapp/connect', async (req: AuthRequest, res: Response) => {
  try {
    await whatsappAdapter.reconnect();
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to start WhatsApp connection', message: error.message });
  }
});

router.post('/whatsapp/disconnect', async (req: AuthRequest, res: Response) => {
  try {
    await whatsappAdapter.disconnect();
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to disconnect WhatsApp', message: error.message });
  }
});

router.post('/whatsapp/link-current', async (req: AuthRequest, res: Response) => {
  try {
    const account = whatsappAdapter.getConnectedAccount();
    if (!account?.jid) {
      return res.status(409).json({ error: 'WHATSAPP_NOT_CONNECTED' });
    }

    const displayName = account.name || account.jid;

    await pool.query(
      `INSERT INTO gitu_linked_accounts (user_id, platform, platform_user_id, display_name, verified, status)
       VALUES ($1, 'whatsapp', $2, $3, true, 'active')
       ON CONFLICT (platform, platform_user_id) DO UPDATE
       SET user_id = EXCLUDED.user_id,
           display_name = EXCLUDED.display_name,
           verified = true,
           status = 'active',
           last_used_at = NOW()`,
      [req.userId, account.jid, displayName]
    );

    res.json({ success: true, platformUserId: account.jid, displayName });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to link WhatsApp account', message: error.message });
  }
});

router.get('/permissions', async (req: AuthRequest, res: Response) => {
  try {
    const resource = typeof req.query.resource === 'string' ? req.query.resource : undefined;
    const permissions = await gituPermissionManager.listPermissions(req.userId!, resource);
    res.json({ success: true, permissions });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list permissions', message: error.message });
  }
});

router.post('/permissions/:id/revoke', async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    await gituPermissionManager.revokePermission(req.userId!, id);
    res.json({ success: true });
  } catch (error: any) {
    const msg = String(error?.message || '');
    const status = msg.toLowerCase().includes('not found') ? 404 : 500;
    res.status(status).json({ error: msg || 'Failed to revoke permission' });
  }
});

router.get('/permissions/requests', async (req: AuthRequest, res: Response) => {
  try {
    const status =
      typeof req.query.status === 'string' && ['pending', 'approved', 'denied'].includes(req.query.status)
        ? (req.query.status as any)
        : undefined;
    const requests = await gituPermissionManager.listPermissionRequests(req.userId!, status);
    res.json({ success: true, requests });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list permission requests', message: error.message });
  }
});

router.post('/permissions/requests', async (req: AuthRequest, res: Response) => {
  try {
    const { resource, actions, scope, reason, expiresAt, expiresInDays } = req.body as any;
    if (!resource || typeof resource !== 'string') return res.status(400).json({ error: 'resource is required' });
    if (!Array.isArray(actions) || actions.some((a: any) => typeof a !== 'string')) {
      return res.status(400).json({ error: 'actions must be an array of strings' });
    }
    if (!reason || typeof reason !== 'string') return res.status(400).json({ error: 'reason is required' });

    let parsedExpiresAt: Date | undefined;
    if (typeof expiresAt === 'string') {
      const d = new Date(expiresAt);
      if (!Number.isNaN(d.getTime())) parsedExpiresAt = d;
    } else if (typeof expiresInDays === 'number' && Number.isFinite(expiresInDays) && expiresInDays > 0) {
      parsedExpiresAt = new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000);
    } else {
      parsedExpiresAt = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000);
    }

    const request = await gituPermissionManager.requestPermission(
      req.userId!,
      { resource, actions, scope, expiresAt: parsedExpiresAt },
      reason
    );
    res.status(201).json({ success: true, request });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to create permission request', message: error.message });
  }
});

router.post('/permissions/requests/:id/approve', async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { expiresAt, expiresInDays } = req.body as any;
    let parsedExpiresAt: Date | undefined;
    if (typeof expiresAt === 'string') {
      const d = new Date(expiresAt);
      if (!Number.isNaN(d.getTime())) parsedExpiresAt = d;
    } else if (typeof expiresInDays === 'number' && Number.isFinite(expiresInDays) && expiresInDays > 0) {
      parsedExpiresAt = new Date(Date.now() + expiresInDays * 24 * 60 * 60 * 1000);
    }

    const permission = await gituPermissionManager.approveRequest(req.userId!, id, { expiresAt: parsedExpiresAt });
    res.json({ success: true, permission });
  } catch (error: any) {
    const msg = String(error?.message || '');
    const status = msg.toLowerCase().includes('not found') ? 404 : msg.toLowerCase().includes('resolved') ? 409 : 500;
    res.status(status).json({ error: msg || 'Failed to approve permission request' });
  }
});

router.post('/permissions/requests/:id/deny', async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    await gituPermissionManager.denyRequest(req.userId!, id);
    res.json({ success: true });
  } catch (error: any) {
    const msg = String(error?.message || '');
    const status = msg.toLowerCase().includes('not found') ? 404 : msg.toLowerCase().includes('resolved') ? 409 : 500;
    res.status(status).json({ error: msg || 'Failed to deny permission request' });
  }
});

router.get('/rules', async (req: AuthRequest, res: Response) => {
  try {
    const enabledRaw = typeof req.query.enabled === 'string' ? req.query.enabled : undefined;
    const enabled =
      enabledRaw === 'true' ? true : enabledRaw === 'false' ? false : undefined;
    const rules = await gituRuleEngine.listRules(req.userId!, { enabled });
    res.json({ success: true, rules });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list rules', message: error.message });
  }
});

router.get('/rules/:id', async (req: AuthRequest, res: Response) => {
  try {
    const rule = await gituRuleEngine.getRule(req.userId!, req.params.id);
    if (!rule) return res.status(404).json({ error: 'RULE_NOT_FOUND' });
    res.json({ success: true, rule });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get rule', message: error.message });
  }
});

router.post('/rules', async (req: AuthRequest, res: Response) => {
  try {
    const rule = await gituRuleEngine.createRule(req.userId!, req.body as any);
    res.status(201).json({ success: true, rule });
  } catch (error: any) {
    const msg = String(error?.message || '');
    const status = msg.includes('NAME_REQUIRED') || msg.includes('TRIGGER_INVALID') || msg.includes('ACTIONS_INVALID') ? 400 : 500;
    res.status(status).json({ error: 'Failed to create rule', message: msg });
  }
});

router.put('/rules/:id', async (req: AuthRequest, res: Response) => {
  try {
    const rule = await gituRuleEngine.updateRule(req.userId!, req.params.id, req.body as any);
    res.json({ success: true, rule });
  } catch (error: any) {
    const msg = String(error?.message || '');
    const status = msg === 'RULE_NOT_FOUND' ? 404 : msg.includes('NAME_REQUIRED') || msg.includes('TRIGGER_INVALID') || msg.includes('ACTIONS_INVALID') ? 400 : 500;
    res.status(status).json({ error: 'Failed to update rule', message: msg });
  }
});

router.delete('/rules/:id', async (req: AuthRequest, res: Response) => {
  try {
    const ok = await gituRuleEngine.deleteRule(req.userId!, req.params.id);
    if (!ok) return res.status(404).json({ error: 'RULE_NOT_FOUND' });
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to delete rule', message: error.message });
  }
});

router.post('/rules/validate', async (req: AuthRequest, res: Response) => {
  try {
    const result = gituRuleEngine.validateRule(req.body as any);
    res.json({ success: true, result });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to validate rule', message: error.message });
  }
});

router.post('/rules/:id/execute', async (req: AuthRequest, res: Response) => {
  try {
    const context = (req.body as any)?.context;
    const result = await gituRuleEngine.executeRule(req.userId!, req.params.id, context);
    res.json({ success: true, result });
  } catch (error: any) {
    const msg = String(error?.message || '');
    const status = msg === 'RULE_NOT_FOUND' ? 404 : 500;
    res.status(status).json({ error: 'Failed to execute rule', message: msg });
  }
});

router.get('/rules/:id/executions', async (req: AuthRequest, res: Response) => {
  try {
    const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 200);
    const offset = Math.max(Number(req.query.offset) || 0, 0);
    const ruleId = req.params.id;

    const result = await pool.query(
      `SELECT id, matched, success, result, error, executed_at
       FROM gitu_rule_executions
       WHERE user_id = $1 AND rule_id = $2
       ORDER BY executed_at DESC
       LIMIT $3 OFFSET $4`,
      [req.userId!, ruleId, limit, offset]
    );

    res.json({ success: true, executions: result.rows });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list rule executions', message: error.message });
  }
});

router.get('/plugins', async (req: AuthRequest, res: Response) => {
  try {
    const enabledRaw = typeof req.query.enabled === 'string' ? req.query.enabled : undefined;
    const enabled = enabledRaw === 'true' ? true : enabledRaw === 'false' ? false : undefined;
    const plugins = await gituPluginSystem.listPlugins(req.userId!, { enabled });
    res.json({ success: true, plugins });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list plugins', message: error.message });
  }
});

router.get('/plugins/catalog', async (req: AuthRequest, res: Response) => {
  try {
    const q = typeof req.query.q === 'string' ? req.query.q.trim() : '';
    const tag = typeof req.query.tag === 'string' ? req.query.tag.trim() : '';
    const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 200);
    const offset = Math.max(Number(req.query.offset) || 0, 0);

    const where: string[] = ['is_active = true'];
    const params: any[] = [];
    let i = 1;

    if (q) {
      where.push(`(slug ILIKE $${i} OR name ILIKE $${i} OR COALESCE(description,'') ILIKE $${i})`);
      params.push(`%${q}%`);
      i++;
    }
    if (tag) {
      where.push(`COALESCE(tags::text, '') ILIKE $${i}`);
      params.push(`%${tag}%`);
      i++;
    }

    params.push(limit, offset);
    const sql = `SELECT id, slug, name, description, entrypoint, version, author, tags, is_active, created_at, updated_at
                 FROM gitu_plugin_catalog
                 WHERE ${where.join(' AND ')}
                 ORDER BY updated_at DESC
                 LIMIT $${i} OFFSET $${i + 1}`;

    const result = await pool.query(sql, params);
    res.json({ success: true, catalog: result.rows, limit, offset });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list plugin catalog', message: error.message });
  }
});

router.get('/plugins/catalog/:id', async (req: AuthRequest, res: Response) => {
  try {
    const result = await pool.query(
      `SELECT id, slug, name, description, code, entrypoint, version, author, tags, is_active, created_at, updated_at
       FROM gitu_plugin_catalog
       WHERE id = $1 AND is_active = true`,
      [req.params.id]
    );
    if (result.rows.length === 0) return res.status(404).json({ error: 'CATALOG_PLUGIN_NOT_FOUND' });
    res.json({ success: true, item: result.rows[0] });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get plugin catalog item', message: error.message });
  }
});

router.post('/plugins/catalog/:id/install', async (req: AuthRequest, res: Response) => {
  try {
    const enabled = typeof (req.body as any)?.enabled === 'boolean' ? (req.body as any).enabled : undefined;
    const config = (req.body as any)?.config;
    const plugin = await gituPluginSystem.installFromCatalog(req.userId!, req.params.id, { enabled, config });
    res.status(201).json({ success: true, plugin });
  } catch (error: any) {
    const msg = String(error?.message || '');
    const status = msg === 'CATALOG_PLUGIN_NOT_FOUND' ? 404 : msg.includes('CONFIG_INVALID') ? 400 : 500;
    res.status(status).json({ error: 'Failed to install plugin', message: msg });
  }
});

router.get('/plugins/:id', async (req: AuthRequest, res: Response) => {
  try {
    const plugin = await gituPluginSystem.getPlugin(req.userId!, req.params.id);
    if (!plugin) return res.status(404).json({ error: 'PLUGIN_NOT_FOUND' });
    res.json({ success: true, plugin });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get plugin', message: error.message });
  }
});

router.post('/plugins', async (req: AuthRequest, res: Response) => {
  try {
    const plugin = await gituPluginSystem.createPlugin(req.userId!, req.body as any);
    res.status(201).json({ success: true, plugin });
  } catch (error: any) {
    const msg = String(error?.message || '');
    const status =
      msg.includes('NAME_REQUIRED') ||
        msg.includes('CODE_REQUIRED') ||
        msg.includes('CODE_DISALLOWED') ||
        msg.includes('CONFIG_INVALID') ||
        msg.includes('FILES_REQUIRED') ||
        msg.includes('FILES_TOO_MANY') ||
        msg.includes('FILE_NAME_INVALID') ||
        msg.includes('FILE_CONTENT_INVALID') ||
        msg.includes('FILE_TOO_LARGE') ||
        msg.includes('FILES_TOTAL_TOO_LARGE') ||
        msg.includes('ENTRY_FILE_MISSING') ||
        msg.includes('PLUGIN_MANIFEST_INVALID')
        ? 400
        : 500;
    res.status(status).json({ error: 'Failed to create plugin', message: msg });
  }
});

router.put('/plugins/:id', async (req: AuthRequest, res: Response) => {
  try {
    const plugin = await gituPluginSystem.updatePlugin(req.userId!, req.params.id, req.body as any);
    res.json({ success: true, plugin });
  } catch (error: any) {
    const msg = String(error?.message || '');
    const status =
      msg === 'PLUGIN_NOT_FOUND'
        ? 404
        : msg.includes('NAME_REQUIRED') ||
          msg.includes('CODE_REQUIRED') ||
          msg.includes('CODE_DISALLOWED') ||
          msg.includes('CONFIG_INVALID') ||
          msg.includes('FILES_REQUIRED') ||
          msg.includes('FILES_TOO_MANY') ||
          msg.includes('FILE_NAME_INVALID') ||
          msg.includes('FILE_CONTENT_INVALID') ||
          msg.includes('FILE_TOO_LARGE') ||
          msg.includes('FILES_TOTAL_TOO_LARGE') ||
          msg.includes('ENTRY_FILE_MISSING') ||
          msg.includes('PLUGIN_MANIFEST_INVALID')
          ? 400
          : 500;
    res.status(status).json({ error: 'Failed to update plugin', message: msg });
  }
});

router.delete('/plugins/:id', async (req: AuthRequest, res: Response) => {
  try {
    const ok = await gituPluginSystem.deletePlugin(req.userId!, req.params.id);
    if (!ok) return res.status(404).json({ error: 'PLUGIN_NOT_FOUND' });
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to delete plugin', message: error.message });
  }
});

router.post('/plugins/validate', async (req: AuthRequest, res: Response) => {
  try {
    const result = gituPluginSystem.validatePlugin(req.body as any);
    res.json({ success: true, result });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to validate plugin', message: error.message });
  }
});

router.post('/plugins/:id/execute', async (req: AuthRequest, res: Response) => {
  try {
    const body = req.body as any;
    const result = await gituPluginSystem.executePlugin(
      req.userId!,
      req.params.id,
      body?.input,
      body?.context,
      { timeoutMs: body?.timeoutMs }
    );
    res.json({ success: true, result });
  } catch (error: any) {
    const msg = String(error?.message || '');
    const status = msg === 'PLUGIN_NOT_FOUND' ? 404 : msg === 'PLUGIN_DISABLED' ? 409 : 500;
    res.status(status).json({ error: 'Failed to execute plugin', message: msg });
  }
});

router.get('/plugins/:id/executions', async (req: AuthRequest, res: Response) => {
  try {
    const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 200);
    const offset = Math.max(Number(req.query.offset) || 0, 0);
    const executions = await gituPluginSystem.listExecutions(req.userId!, req.params.id, limit, offset);
    res.json({ success: true, executions });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list plugin executions', message: error.message });
  }
});

// ==================== MEMORIES ====================

router.get('/memories', async (req: AuthRequest, res: Response) => {
  try {
    const { category, verified, tags, limit, offset, query } = req.query as any;

    // Check if it's a search or list
    if (typeof query === 'string' && query.length > 0) {
      const memories = await gituMemoryService.searchMemories(
        req.userId!,
        query,
        limit ? Number(limit) : 20
      );
      return res.json({ success: true, memories });
    }

    // List with filters
    const filters: any = {};
    if (category) filters.category = category;
    if (verified !== undefined) filters.verified = verified === 'true';
    if (tags) filters.tags = Array.isArray(tags) ? tags : [tags];
    if (limit) filters.limit = Number(limit);
    if (offset) filters.offset = Number(offset);

    const memories = await gituMemoryService.listMemories(req.userId!, filters);
    res.json({ success: true, memories });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list memories', message: error.message });
  }
});

router.post('/memories/:id/confirm', async (req: AuthRequest, res: Response) => {
  try {
    const memory = await gituMemoryService.confirmMemory(req.userId!, req.params.id);
    res.json({ success: true, memory });
  } catch (error: any) {
    if (String(error?.message) === 'MEMORY_NOT_FOUND') {
      return res.status(404).json({ error: 'Memory not found' });
    }
    res.status(500).json({ error: 'Failed to confirm memory', message: error.message });
  }
});

router.post('/memories/:id/request-verification', async (req: AuthRequest, res: Response) => {
  try {
    const memory = await gituMemoryService.requestVerification(req.userId!, req.params.id);
    res.json({ success: true, memory });
  } catch (error: any) {
    if (String(error?.message) === 'MEMORY_NOT_FOUND') {
      return res.status(404).json({ error: 'Memory not found' });
    }
    res.status(500).json({ error: 'Failed to request verification', message: error.message });
  }
});

router.post('/memories/:id/correct', async (req: AuthRequest, res: Response) => {
  try {
    const memory = await gituMemoryService.correctMemory(req.userId!, req.params.id, req.body);
    res.json({ success: true, memory });
  } catch (error: any) {
    if (String(error?.message) === 'MEMORY_NOT_FOUND') {
      return res.status(404).json({ error: 'Memory not found' });
    }
    res.status(500).json({ error: 'Failed to correct memory', message: error.message });
  }
});

router.delete('/memories/:id', async (req: AuthRequest, res: Response) => {
  try {
    await gituMemoryService.deleteMemory(req.userId!, req.params.id);
    res.json({ success: true });
  } catch (error: any) {
    if (String(error?.message) === 'MEMORY_NOT_FOUND') {
      return res.status(404).json({ error: 'Memory not found' });
    }
    res.status(500).json({ error: 'Failed to delete memory', message: error.message });
  }
});

// ==================== SCHEDULED TASKS ====================

/**
 * GET /tasks
 * List all scheduled tasks for the user
 */
router.get('/tasks', async (req: AuthRequest, res: Response) => {
  try {
    const result = await pool.query(
      `SELECT * FROM gitu_scheduled_tasks WHERE user_id = $1 ORDER BY created_at DESC`,
      [req.userId]
    );
    res.json({ success: true, tasks: result.rows });
  } catch (error: any) {
    console.error('List tasks error:', error);
    res.status(500).json({ error: 'Failed to list tasks', message: error.message });
  }
});

/**
 * POST /tasks
 * Create a new scheduled task
 */
router.post('/tasks', async (req: AuthRequest, res: Response) => {
  try {
    const { name, action, cron, enabled = true, trigger = 'cron' } = req.body;

    if (!name || !action || !cron) {
      return res.status(400).json({ error: 'Name, action, and cron are required' });
    }

    const id = uuidv4();
    const result = await pool.query(
      `INSERT INTO gitu_scheduled_tasks (id, user_id, name, action, cron, enabled, trigger)
             VALUES ($1, $2, $3, $4, $5, $6, $7)
             RETURNING *`,
      [id, req.userId, name, action, cron, enabled, trigger]
    );

    res.json({ success: true, task: result.rows[0] });
  } catch (error: any) {
    console.error('Create task error:', error);
    res.status(500).json({ error: 'Failed to create task', message: error.message });
  }
});

/**
 * PUT /tasks/:id
 * Update a scheduled task
 */
router.put('/tasks/:id', async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { name, action, cron, enabled, trigger } = req.body;

    // Verify ownership
    const check = await pool.query(
      'SELECT id FROM gitu_scheduled_tasks WHERE id = $1 AND user_id = $2',
      [id, req.userId]
    );
    if (check.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const result = await pool.query(
      `UPDATE gitu_scheduled_tasks 
             SET name = COALESCE($1, name),
                 action = COALESCE($2, action),
                 cron = COALESCE($3, cron),
                 enabled = COALESCE($4, enabled),
                 trigger = COALESCE($5, trigger),
                 updated_at = NOW()
             WHERE id = $6
             RETURNING *`,
      [name, action, cron, enabled, trigger, id]
    );

    res.json({ success: true, task: result.rows[0] });
  } catch (error: any) {
    console.error('Update task error:', error);
    res.status(500).json({ error: 'Failed to update task', message: error.message });
  }
});

/**
 * DELETE /tasks/:id
 * Delete a scheduled task
 */
router.delete('/tasks/:id', async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const result = await pool.query(
      'DELETE FROM gitu_scheduled_tasks WHERE id = $1 AND user_id = $2 RETURNING id',
      [id, req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    res.json({ success: true, id });
  } catch (error: any) {
    console.error('Delete task error:', error);
    res.status(500).json({ error: 'Failed to delete task', message: error.message });
  }
});

/**
 * POST /tasks/:id/trigger
 * Manually trigger a task immediately
 */
router.post('/tasks/:id/trigger', async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;

    // Verify ownership and get task details
    const result = await pool.query(
      'SELECT * FROM gitu_scheduled_tasks WHERE id = $1 AND user_id = $2',
      [id, req.userId]
    );

    if (result.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const task = result.rows[0];

    // Use trigger logic from scheduler
    // Since executeTask is private, we'll use trigger() which creates a manual task, 
    // OR we can expose executeTask publicly. 
    // For now, let's just use trigger() with the task's action.
    // Ideally we'd want to record this execution against the specific task ID, 
    // but gituScheduler.trigger() creates a new ID 'manual-...'.
    // Let's rely on gituScheduler.trigger() for now as it's safe.

    // Cast action to AllowedAction (assuming DB has valid actions)
    await gituScheduler.trigger(task.action as any, req.userId!);

    res.json({ success: true, message: 'Task triggered successfully' });
  } catch (error: any) {
    console.error('Trigger task error:', error);
    res.status(500).json({ error: 'Failed to trigger task', message: error.message });
  }
});

/**
 * GET /tasks/:id/executions
 * Get execution history for a task
 */
router.get('/tasks/:id/executions', async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { limit = 20 } = req.query;

    // Verify ownership
    const check = await pool.query(
      'SELECT id FROM gitu_scheduled_tasks WHERE id = $1 AND user_id = $2',
      [id, req.userId]
    );
    if (check.rows.length === 0) {
      return res.status(404).json({ error: 'Task not found' });
    }

    const result = await pool.query(
      `SELECT * FROM gitu_task_executions 
             WHERE task_id = $1 
             ORDER BY executed_at DESC 
             LIMIT $2`,
      [id, limit]
    );

    res.json({ success: true, executions: result.rows });
  } catch (error: any) {
    console.error('List executions error:', error);
    res.status(500).json({ error: 'Failed to list executions', message: error.message });
  }
});

// export default removed

// ==================== IDENTITY MANAGER ====================
router.get('/identity/linked', async (req: AuthRequest, res: Response) => {
  try {
    const accounts = await gituIdentityManager.listLinkedAccounts(req.userId!);
    res.json({ success: true, accounts });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list linked accounts', message: error.message });
  }
});

router.post('/identity/link', async (req: AuthRequest, res: Response) => {
  try {
    const { platform, platformUserId, displayName } = req.body;
    console.log(`[Identity Link] Attempting to link: userId=${req.userId}, platform=${platform}, platformUserId=${platformUserId}`);

    if (!platform || !platformUserId) {
      return res.status(400).json({ error: 'platform and platformUserId are required' });
    }
    const account = await gituIdentityManager.linkAccount({
      userId: req.userId!,
      platform,
      platformUserId: String(platformUserId).trim(), // Ensure string and trim whitespace
      displayName,
    });
    console.log(`[Identity Link] SUCCESS: Linked ${platform}:${platformUserId} to user ${req.userId}`);
    res.json({ success: true, account });
  } catch (error: any) {
    console.error(`[Identity Link] FAILED:`, error);
    res.status(500).json({ error: 'Failed to link account', message: error.message });
  }
});

router.post('/identity/unlink', async (req: AuthRequest, res: Response) => {
  try {
    const { platform, platformUserId } = req.body;
    if (!platform || !platformUserId) {
      return res.status(400).json({ error: 'platform and platformUserId are required' });
    }
    const ok = await gituIdentityManager.unlinkAccount(req.userId!, platform, platformUserId);
    if (!ok) return res.status(404).json({ error: 'Account not found' });
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to unlink account', message: error.message });
  }
});

router.post('/identity/set-primary', async (req: AuthRequest, res: Response) => {
  try {
    const { platform, platformUserId } = req.body;
    if (!platform || !platformUserId) {
      return res.status(400).json({ error: 'platform and platformUserId are required' });
    }
    const account = await gituIdentityManager.setPrimary(req.userId!, platform, platformUserId);
    if (!account) return res.status(404).json({ error: 'Account not found' });
    res.json({ success: true, account });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to set primary account', message: error.message });
  }
});

router.post('/identity/verify', async (req: AuthRequest, res: Response) => {
  try {
    const { platform, platformUserId } = req.body;
    if (!platform || !platformUserId) {
      return res.status(400).json({ error: 'platform and platformUserId are required' });
    }
    const account = await gituIdentityManager.verifyAccount(req.userId!, platform, platformUserId);
    if (!account) return res.status(404).json({ error: 'Account not found' });
    res.json({ success: true, account });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to verify account', message: error.message });
  }
});

router.get('/identity/trust-levels', async (req: AuthRequest, res: Response) => {
  try {
    const levels = await gituIdentityManager.getTrustLevels(req.userId!);
    res.json({ success: true, levels });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get trust levels', message: error.message });
  }
});

router.get('/files/list', async (req: AuthRequest, res: Response) => {
  try {
    const p = (req.query.path as string) || '.';
    const ok = await gituPermissionManager.checkPermission(req.userId!, {
      resource: 'files',
      action: 'read',
      scope: { path: normalizeScopePath(p) },
    });
    if (!ok) return res.status(403).json({ success: false, error: 'FILE_ACCESS_DENIED' });
    const entries = await listDir(req.userId!, p);
    res.json({ success: true, entries });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list directory', message: error.message });
  }
});

router.get('/files/permissions', async (req: AuthRequest, res: Response) => {
  try {
    const permissions = await gituPermissionManager.listPermissions(req.userId!, 'files');
    const now = new Date();
    const active = permissions.filter(p => !p.revokedAt && (!p.expiresAt || p.expiresAt > now));
    if (active.length === 0) {
      return res.json({ success: true, active: false, allowedPaths: [], actions: [] });
    }

    const allowedPaths = new Set<string>();
    const actions = new Set<string>();
    const permissionIds: string[] = [];
    const expiresAt = active
      .map(p => p.expiresAt)
      .filter(Boolean)
      .sort((a, b) => a!.getTime() - b!.getTime())[0];

    for (const p of active) {
      permissionIds.push(p.id);
      for (const action of p.actions) actions.add(action);
      const scopeAllowed = p.scope?.allowedPaths ?? [];
      for (const ap of scopeAllowed) allowedPaths.add(ap);
    }

    res.json({
      success: true,
      active: true,
      permissionIds,
      actions: Array.from(actions),
      allowedPaths: Array.from(allowedPaths),
      expiresAt: expiresAt ? expiresAt.toISOString() : null,
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get file permissions', message: error.message });
  }
});

router.put('/files/permissions', async (req: AuthRequest, res: Response) => {
  try {
    const { allowedPaths } = req.body as { allowedPaths?: unknown };
    if (!Array.isArray(allowedPaths)) {
      return res.status(400).json({ error: 'allowedPaths must be an array of strings' });
    }

    const cleaned = Array.from(
      new Set(
        allowedPaths
          .filter((p): p is string => typeof p === 'string')
          .map(p => normalizeScopePath(p))
          .filter(p => p.length > 0)
      )
    );

    if (cleaned.length === 0) {
      const count = await gituPermissionManager.revokeAllPermissions(req.userId!, 'files');
      return res.json({ success: true, active: false, revoked: count, allowedPaths: [] });
    }

    const permissions = await gituPermissionManager.listPermissions(req.userId!, 'files');
    const now = new Date();
    const active = permissions.filter(p => !p.revokedAt && (!p.expiresAt || p.expiresAt > now));
    const latest = active[0];

    if (!latest || !latest.actions.includes('read') || !latest.actions.includes('write')) {
      if (active.length > 0) {
        await gituPermissionManager.revokeAllPermissions(req.userId!, 'files');
      }
      const created = await gituPermissionManager.grantPermission(req.userId!, {
        resource: 'files',
        actions: ['read', 'write'],
        scope: { allowedPaths: cleaned },
      });
      return res.json({
        success: true,
        active: true,
        permissionIds: [created.id],
        actions: created.actions,
        allowedPaths: cleaned,
        expiresAt: created.expiresAt ? created.expiresAt.toISOString() : null,
      });
    }

    const updated = await gituPermissionManager.updatePermission(latest.id, {
      scope: { ...(latest.scope ?? {}), allowedPaths: cleaned },
    });
    res.json({
      success: true,
      active: true,
      permissionIds: [updated.id],
      actions: updated.actions,
      allowedPaths: cleaned,
      expiresAt: updated.expiresAt ? updated.expiresAt.toISOString() : null,
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to update file permissions', message: error.message });
  }
});

router.post('/files/permissions/revoke', async (req: AuthRequest, res: Response) => {
  try {
    const count = await gituPermissionManager.revokeAllPermissions(req.userId!, 'files');
    res.json({ success: true, revoked: count });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to revoke file access', message: error.message });
  }
});

router.get('/files/audit-logs', async (req: AuthRequest, res: Response) => {
  try {
    const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 200);
    const offset = Math.max(Number(req.query.offset) || 0, 0);
    const action = typeof req.query.action === 'string' ? req.query.action : undefined;
    const successRaw = typeof req.query.success === 'string' ? req.query.success : undefined;
    const pathPrefixRaw = typeof req.query.pathPrefix === 'string' ? req.query.pathPrefix : undefined;

    const where: string[] = ['user_id = $1'];
    const params: any[] = [req.userId!];
    let i = 2;

    if (action) {
      where.push(`action = $${i++}`);
      params.push(action);
    }

    if (successRaw === 'true' || successRaw === 'false') {
      where.push(`success = $${i++}`);
      params.push(successRaw === 'true');
    }

    if (pathPrefixRaw) {
      where.push(`path LIKE $${i++}`);
      params.push(`${normalizeScopePath(pathPrefixRaw)}%`);
    }

    params.push(limit);
    params.push(offset);

    const result = await pool.query(
      `SELECT id, action, path, success, error_message, created_at
       FROM file_audit_logs
       WHERE ${where.join(' AND ')}
       ORDER BY created_at DESC
       LIMIT $${i++} OFFSET $${i++}`,
      params
    );

    res.json({ success: true, logs: result.rows });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list file operation logs', message: error.message });
  }
});

router.get('/shell/permissions', async (req: AuthRequest, res: Response) => {
  try {
    const permissions = await gituPermissionManager.listPermissions(req.userId!, 'shell');
    const now = new Date();
    const active = permissions.filter(p => !p.revokedAt && (!p.expiresAt || p.expiresAt > now));
    if (active.length === 0) {
      return res.json({
        success: true,
        active: false,
        allowedCommands: [],
        allowedPaths: [],
        actions: [],
        allowUnsandboxed: false,
      });
    }

    const allowedCommands = new Set<string>();
    const allowedPaths = new Set<string>();
    const actions = new Set<string>();
    const permissionIds: string[] = [];
    const expiresAt = active
      .map(p => p.expiresAt)
      .filter(Boolean)
      .sort((a, b) => a!.getTime() - b!.getTime())[0];

    let allowUnsandboxed = false;
    for (const p of active) {
      permissionIds.push(p.id);
      for (const action of p.actions) actions.add(action);
      const scopeAllowedCommands = p.scope?.allowedCommands ?? [];
      for (const ac of scopeAllowedCommands) allowedCommands.add(ac);
      const scopeAllowedPaths = p.scope?.allowedPaths ?? [];
      for (const ap of scopeAllowedPaths) allowedPaths.add(ap);
      if ((p.scope as any)?.customScope?.allowUnsandboxed === true) allowUnsandboxed = true;
    }

    res.json({
      success: true,
      active: true,
      permissionIds,
      actions: Array.from(actions),
      allowedCommands: Array.from(allowedCommands),
      allowedPaths: Array.from(allowedPaths),
      allowUnsandboxed,
      expiresAt: expiresAt ? expiresAt.toISOString() : null,
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get shell permissions', message: error.message });
  }
});

router.put('/shell/permissions', async (req: AuthRequest, res: Response) => {
  try {
    const body = req.body as { allowedCommands?: unknown; allowedPaths?: unknown; allowUnsandboxed?: unknown };
    if (!Array.isArray(body.allowedCommands)) {
      return res.status(400).json({ error: 'allowedCommands must be an array of strings' });
    }

    const allowedCommands = Array.from(
      new Set(
        body.allowedCommands
          .filter((c): c is string => typeof c === 'string')
          .map(c => c.trim())
          .filter(c => c.length > 0)
      )
    );

    const allowedPaths = Array.isArray(body.allowedPaths)
      ? Array.from(
        new Set(
          body.allowedPaths
            .filter((p): p is string => typeof p === 'string')
            .map(p => normalizeScopePath(p))
            .filter(p => p.length > 0)
        )
      )
      : [];

    const allowUnsandboxed = body.allowUnsandboxed === true;

    if (allowUnsandboxed) {
      const userResult = await pool.query('SELECT role FROM users WHERE id = $1', [req.userId]);
      const role = userResult.rows[0]?.role || 'user';
      if (role !== 'admin') {
        return res.status(403).json({ error: 'FORBIDDEN', message: 'Only admins can enable unsandboxed mode' });
      }
    }

    if (allowedCommands.length === 0) {
      const count = await gituPermissionManager.revokeAllPermissions(req.userId!, 'shell');
      return res.json({ success: true, active: false, revoked: count, allowedCommands: [], allowedPaths: [] });
    }

    const permissions = await gituPermissionManager.listPermissions(req.userId!, 'shell');
    const now = new Date();
    const active = permissions.filter(p => !p.revokedAt && (!p.expiresAt || p.expiresAt > now));
    const latest = active[0];

    const newScope: any = { allowedCommands, allowedPaths };
    if (allowUnsandboxed) newScope.customScope = { ...(latest?.scope as any)?.customScope, allowUnsandboxed: true };

    if (!latest || !latest.actions.includes('execute')) {
      if (active.length > 0) {
        await gituPermissionManager.revokeAllPermissions(req.userId!, 'shell');
      }
      const created = await gituPermissionManager.grantPermission(req.userId!, {
        resource: 'shell',
        actions: ['execute'],
        scope: newScope,
      });
      return res.json({
        success: true,
        active: true,
        permissionIds: [created.id],
        actions: created.actions,
        allowedCommands,
        allowedPaths,
        allowUnsandboxed,
        expiresAt: created.expiresAt ? created.expiresAt.toISOString() : null,
      });
    }

    const updated = await gituPermissionManager.updatePermission(latest.id, { scope: newScope });
    res.json({
      success: true,
      active: true,
      permissionIds: [updated.id],
      actions: updated.actions,
      allowedCommands,
      allowedPaths,
      allowUnsandboxed,
      expiresAt: updated.expiresAt ? updated.expiresAt.toISOString() : null,
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to update shell permissions', message: error.message });
  }
});

router.post('/shell/permissions/revoke', async (req: AuthRequest, res: Response) => {
  try {
    const count = await gituPermissionManager.revokeAllPermissions(req.userId!, 'shell');
    res.json({ success: true, revoked: count });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to revoke shell access', message: error.message });
  }
});

router.post('/shell/execute', authenticateToken, async (req: AuthRequest, res: Response) => {
  try {
    const { command, args, cwd, timeoutMs, sandboxed, dryRun } = req.body as any;
    const result = await gituShellManager.execute(req.userId!, {
      command,
      args,
      cwd,
      timeoutMs,
      sandboxed,
      dryRun,
    });
    const e = result.error;
    const isPermissionError =
      typeof e === 'string' &&
      (e.startsWith('SHELL_') || e === 'UNSANDBOXED_MODE_NOT_ALLOWED' || e === 'CWD_REQUIRED_FOR_SANDBOX');
    const status = e === 'COMMAND_REQUIRED' ? 400 : isPermissionError ? 403 : 200;
    res.status(status).json({ success: result.success, result });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to execute shell command', message: error.message });
  }
});

router.get('/shell/audit-logs', async (req: AuthRequest, res: Response) => {
  try {
    const limit = Math.min(Math.max(Number(req.query.limit) || 50, 1), 200);
    const offset = Math.max(Number(req.query.offset) || 0, 0);
    const mode = typeof req.query.mode === 'string' ? req.query.mode : undefined;
    const successRaw = typeof req.query.success === 'string' ? req.query.success : undefined;

    const where: string[] = ['user_id = $1'];
    const params: any[] = [req.userId!];
    let i = 2;

    if (mode) {
      where.push(`mode = $${i++}`);
      params.push(mode);
    }

    if (successRaw === 'true' || successRaw === 'false') {
      where.push(`success = $${i++}`);
      params.push(successRaw === 'true');
    }

    params.push(limit);
    params.push(offset);

    const result = await pool.query(
      `SELECT id, mode, command, args, cwd, success, exit_code, error_message, duration_ms, stdout_bytes, stderr_bytes, stdout_truncated, stderr_truncated, created_at
       FROM gitu_shell_audit_logs
       WHERE ${where.join(' AND ')}
       ORDER BY created_at DESC
       LIMIT $${i++} OFFSET $${i++}`,
      params
    );

    res.json({ success: true, logs: result.rows });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list shell audit logs', message: error.message });
  }
});

// ==================== GMAIL OAUTH ====================
const gmailStates = new Map<string, { userId: string; expiresAt: number }>();

router.get('/gmail/status', async (req: AuthRequest, res: Response) => {
  try {
    const connected = await gituGmailManager.isConnected(req.userId!);
    const connection = connected ? await gituGmailManager.getConnection(req.userId!) : null;
    res.json({
      success: true,
      connected,
      connection: connection ? {
        email: connection.email,
        scopes: connection.scopes,
        connectedAt: connection.created_at,
        lastUsedAt: connection.last_used_at,
      } : null,
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to check Gmail status', message: error.message });
  }
});

router.post('/gmail/disconnect', async (req: AuthRequest, res: Response) => {
  try {
    await gituGmailManager.disconnect(req.userId!);
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to disconnect Gmail', message: error.message });
  }
});

router.get('/gmail/auth-url', async (req: AuthRequest, res: Response) => {
  try {
    const state = uuidv4();
    gmailStates.set(state, { userId: req.userId!, expiresAt: Date.now() + 10 * 60 * 1000 });
    const authUrl = gituGmailManager.getAuthUrl(state);
    res.json({ success: true, authUrl, state });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get Gmail auth URL', message: error.message });
  }
});

router.get('/gmail/callback', async (req: any, res: any) => {
  try {
    const { code, state, error } = req.query;
    if (error) {
      return res.redirect(`/settings?gmail_error=${encodeURIComponent(error as string)}`);
    }
    if (!code || !state) {
      return res.redirect('/settings?gmail_error=missing_params');
    }
    const stateData = gmailStates.get(state as string);
    if (!stateData || stateData.expiresAt < Date.now()) {
      gmailStates.delete(state as string);
      return res.redirect('/settings?gmail_error=invalid_state');
    }
    const userId = stateData.userId;
    gmailStates.delete(state as string);

    const tokenData = await gituGmailManager.exchangeCodeForToken(code as string);
    await gituGmailManager.connect(userId, tokenData);

    res.redirect('/settings?gmail_connected=true');
  } catch (error: any) {
    res.redirect(`/settings?gmail_error=${encodeURIComponent(error.message)}`);
  }
});

router.get('/gmail/messages', async (req: AuthRequest, res: Response) => {
  try {
    const { query, maxResults } = req.query as any;
    const connected = await gituGmailManager.isConnected(req.userId!);
    if (!connected) {
      return res.status(401).json({ success: false, error: 'GMAIL_NOT_CONNECTED' });
    }
    const data = await gmailList(req.userId!, query, Number(maxResults) || 20);
    res.json({ success: true, messages: data.messages || [], nextPageToken: data.nextPageToken });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list messages', message: error.message });
  }
});

router.get('/gmail/message/:id', async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const connected = await gituGmailManager.isConnected(req.userId!);
    if (!connected) {
      return res.status(401).json({ success: false, error: 'GMAIL_NOT_CONNECTED' });
    }
    const data = await gmailGet(req.userId!, id);
    res.json({ success: true, message: data });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get message', message: error.message });
  }
});

router.post('/gmail/send', async (req: AuthRequest, res: Response) => {
  try {
    const { to, subject, body, from } = req.body;
    if (!to || !subject || !body) {
      return res.status(400).json({ error: 'to, subject, and body are required' });
    }
    const connected = await gituGmailManager.isConnected(req.userId!);
    if (!connected) {
      return res.status(401).json({ success: false, error: 'GMAIL_NOT_CONNECTED' });
    }
    const data = await gmailSend(req.userId!, to, subject, body, from);
    res.json({ success: true, result: data });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to send email', message: error.message });
  }
});

router.get('/gmail/labels', async (req: AuthRequest, res: Response) => {
  try {
    const connected = await gituGmailManager.isConnected(req.userId!);
    if (!connected) {
      return res.status(401).json({ success: false, error: 'GMAIL_NOT_CONNECTED' });
    }
    const data = await gmailLabels(req.userId!);
    res.json({ success: true, labels: data.labels || [] });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list labels', message: error.message });
  }
});

router.post('/gmail/message/:id/labels', async (req: AuthRequest, res: Response) => {
  try {
    const { id } = req.params;
    const { addLabelIds, removeLabelIds } = req.body;
    const connected = await gituGmailManager.isConnected(req.userId!);
    if (!connected) {
      return res.status(401).json({ success: false, error: 'GMAIL_NOT_CONNECTED' });
    }
    const data = await gmailModifyLabels(req.userId!, id, addLabelIds, removeLabelIds);
    res.json({ success: true, result: data });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to modify labels', message: error.message });
  }
});

router.post('/gmail/ai/summarize', async (req: AuthRequest, res: Response) => {
  try {
    const { text } = req.body;
    if (!text || typeof text !== 'string') {
      return res.status(400).json({ error: 'text is required' });
    }
    const result = summarizeEmail(text);
    res.json({ success: true, summary: result });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to summarize email', message: error.message });
  }
});

router.post('/gmail/ai/suggest-replies', async (req: AuthRequest, res: Response) => {
  try {
    const { text } = req.body;
    if (!text || typeof text !== 'string') {
      return res.status(400).json({ error: 'text is required' });
    }
    const result = suggestReplies(text);
    res.json({ success: true, replies: result });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to suggest replies', message: error.message });
  }
});

router.post('/gmail/ai/actions', async (req: AuthRequest, res: Response) => {
  try {
    const { text } = req.body;
    if (!text || typeof text !== 'string') {
      return res.status(400).json({ error: 'text is required' });
    }
    const result = extractActionItems(text);
    res.json({ success: true, actions: result });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to extract actions', message: error.message });
  }
});

router.post('/gmail/ai/sentiment', async (req: AuthRequest, res: Response) => {
  try {
    const { text } = req.body;
    if (!text || typeof text !== 'string') {
      return res.status(400).json({ error: 'text is required' });
    }
    const result = analyzeSentiment(text);
    res.json({ success: true, sentiment: result });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to analyze sentiment', message: error.message });
  }
});
router.get('/files/read', async (req: AuthRequest, res: Response) => {
  try {
    const p = req.query.path as string;
    if (!p) return res.status(400).json({ error: 'path is required' });
    const ok = await gituPermissionManager.checkPermission(req.userId!, {
      resource: 'files',
      action: 'read',
      scope: { path: normalizeScopePath(p) },
    });
    if (!ok) return res.status(403).json({ success: false, error: 'FILE_ACCESS_DENIED' });
    const data = await readFile(req.userId!, p);
    res.json({ success: true, content: data });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to read file', message: error.message });
  }
});

router.post('/files/write', async (req: AuthRequest, res: Response) => {
  try {
    const { path: p, content } = req.body;
    if (!p || typeof content !== 'string') {
      return res.status(400).json({ error: 'path and content are required' });
    }
    const ok = await gituPermissionManager.checkPermission(req.userId!, {
      resource: 'files',
      action: 'write',
      scope: { path: normalizeScopePath(p) },
    });
    if (!ok) return res.status(403).json({ success: false, error: 'FILE_ACCESS_DENIED' });
    await writeFile(req.userId!, p, content);
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to write file', message: error.message });
  }
});

// ==================== GITU AGENTS ====================

router.get('/agents', async (req: AuthRequest, res: Response) => {
  try {
    const agents = await gituAgentManager.listAgents(req.userId!);
    res.json({ success: true, agents });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list agents', message: error.message });
  }
});

router.post('/agents', async (req: AuthRequest, res: Response) => {
  try {
    const { task, parentAgentId, memory } = req.body;
    if (!task) return res.status(400).json({ error: 'task is required' });

    const agent = await gituAgentManager.spawnAgent(req.userId!, task, {
      role: 'autonomous_agent',
      focus: 'general',
      parentAgentId
    });
    res.status(201).json({ success: true, agent });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to spawn agent', message: error.message });
  }
});

router.get('/agents/:id', async (req: AuthRequest, res: Response) => {
  try {
    const agent = await gituAgentManager.getAgent(req.params.id);
    if (!agent) return res.status(404).json({ error: 'Agent not found' });
    if (agent.userId !== req.userId) return res.status(403).json({ error: 'Access denied' });

    res.json({ success: true, agent });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get agent', message: error.message });
  }
});

// ==================== SHOPIFY INTEGRATION ====================

router.get('/shopify/status', async (req: AuthRequest, res: Response) => {
  try {
    const connected = await gituShopifyManager.isConnected(req.userId!);
    const details = connected ? await gituShopifyManager.getConnectionDetails(req.userId!) : null;
    res.json({
      success: true,
      connected,
      shop: details ? {
        storeDomain: details.store_domain,
        name: details.shop_name,
        email: details.shop_email,
        plan: details.shop_plan,
        connectedAt: details.created_at,
      } : null,
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to check Shopify status', message: error.message });
  }
});

router.post('/shopify/connect', async (req: AuthRequest, res: Response) => {
  try {
    const { storeDomain, accessToken, apiVersion } = req.body;
    if (!storeDomain || !accessToken) {
      return res.status(400).json({ error: 'storeDomain and accessToken are required' });
    }

    const credentials = { storeDomain, accessToken, apiVersion };

    // Test connection first
    const testResult = await gituShopifyManager.testConnection(credentials);

    // Save connection
    await gituShopifyManager.connect(req.userId!, credentials, testResult.shop);

    res.json({ success: true, shop: testResult.shop });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to connect Shopify', message: error.message });
  }
});

router.post('/shopify/disconnect', async (req: AuthRequest, res: Response) => {
  try {
    await gituShopifyManager.disconnect(req.userId!);
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to disconnect Shopify', message: error.message });
  }
});

// ==================== PROACTIVE INSIGHTS ====================

/**
 * GET /proactive-insights
 * Get aggregated proactive insights for the user
 */
router.get('/proactive-insights', async (req: AuthRequest, res: Response) => {
  try {
    const useCache = req.query.refresh !== 'true';
    const insights = await gituProactiveService.getProactiveInsights(req.userId!, useCache);
    res.json({ success: true, insights });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get proactive insights', message: error.message });
  }
});

/**
 * GET /proactive-insights/gmail
 * Get Gmail summary only
 */
router.get('/proactive-insights/gmail', async (req: AuthRequest, res: Response) => {
  try {
    const summary = await gituProactiveService.getGmailSummary(req.userId!);
    res.json({ success: true, summary });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get Gmail summary', message: error.message });
  }
});

/**
 * GET /proactive-insights/whatsapp
 * Get WhatsApp summary only
 */
router.get('/proactive-insights/whatsapp', async (req: AuthRequest, res: Response) => {
  try {
    const summary = await gituProactiveService.getWhatsAppSummary(req.userId!);
    res.json({ success: true, summary });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get WhatsApp summary', message: error.message });
  }
});

/**
 * GET /proactive-insights/tasks
 * Get scheduled tasks summary only
 */
router.get('/proactive-insights/tasks', async (req: AuthRequest, res: Response) => {
  try {
    const summary = await gituProactiveService.getTasksSummary(req.userId!);
    res.json({ success: true, summary });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get tasks summary', message: error.message });
  }
});

/**
 * GET /proactive-insights/suggestions
 * Get AI-generated suggestions only
 */
router.get('/proactive-insights/suggestions', async (req: AuthRequest, res: Response) => {
  try {
    const suggestions = await gituProactiveService.generateSuggestions(req.userId!);
    res.json({ success: true, suggestions });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get suggestions', message: error.message });
  }
});

/**
 * GET /proactive-insights/patterns
 * Get AI-analyzed usage patterns
 */
router.get('/proactive-insights/patterns', async (req: AuthRequest, res: Response) => {
  try {
    const patterns = await gituProactiveService.analyzePatterns(req.userId!);
    res.json({ success: true, patterns });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to analyze patterns', message: error.message });
  }
});

/**
 * POST /proactive-insights/activity
 * Record user activity for pattern analysis
 */
router.post('/proactive-insights/activity', async (req: AuthRequest, res: Response) => {
  try {
    const { activityType, metadata } = req.body;
    if (!activityType || typeof activityType !== 'string') {
      return res.status(400).json({ error: 'activityType is required' });
    }
    await gituProactiveService.recordActivity(req.userId!, activityType, metadata);
    res.json({ success: true });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to record activity', message: error.message });
  }
});

/**
 * POST /proactive-insights/refresh
 * Force refresh of proactive insights cache
 */
router.post('/proactive-insights/refresh', async (req: AuthRequest, res: Response) => {
  try {
    gituProactiveService.clearCache(req.userId!);
    const insights = await gituProactiveService.getProactiveInsights(req.userId!, false);
    res.json({ success: true, insights });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to refresh insights', message: error.message });
  }
});

// ==================== SWARM MISSIONS ====================

/**
 * POST /mission
 * Start a new Autonomous Swarm Mission
 */
const startMissionHandler = async (req: AuthRequest, res: Response) => {
  try {
    const { objective } = req.body;
    if (!objective || typeof objective !== 'string') {
      return res.status(400).json({ error: 'objective is required' });
    }

    const mission = await gituProactiveService.startMission(req.userId!, objective);
    res.status(201).json({ success: true, mission });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to start mission', message: error.message });
  }
};

router.post('/mission', startMissionHandler);

router.post('/improvement/start', async (req: AuthRequest, res: Response) => {
  try {
    const { objective, targetPaths, verificationCommands } = req.body as any;
    if (!objective || typeof objective !== 'string') {
      return res.status(400).json({ error: 'objective is required' });
    }
    if (!Array.isArray(targetPaths) || targetPaths.length === 0 || !targetPaths.every((p: any) => typeof p === 'string')) {
      return res.status(400).json({ error: 'targetPaths must be a non-empty string array' });
    }
    if (targetPaths.length > 10) {
      return res.status(400).json({ error: 'targetPaths too large (max 10)' });
    }

    const result = await gituSelfImprovementService.startSelfImprovement({
      userId: req.userId!,
      objective,
      targetPaths,
      verificationCommands: Array.isArray(verificationCommands) ? verificationCommands : undefined
    });

    res.status(201).json({ success: true, ...result });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to start self-improvement', message: error.message });
  }
});

router.post('/improvement/:id/verify', async (req: AuthRequest, res: Response) => {
  try {
    const mission = await gituSelfImprovementService.runVerification(req.userId!, req.params.id);
    res.json({ success: true, mission });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to verify self-improvement proposal', message: error.message });
  }
});

router.post('/improvement/:id/apply', async (req: AuthRequest, res: Response) => {
  try {
    const { confirm } = req.body as any;
    if (confirm !== true) {
      return res.status(400).json({ error: 'confirm must be true to apply a proposal' });
    }
    const mission = await gituSelfImprovementService.applyProposal(req.userId!, req.params.id);
    res.json({ success: true, mission });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to apply self-improvement proposal', message: error.message });
  }
});

/**
 * GET /mission/active
 * data-stream of active missions (polled by frontend)
 */
router.get('/mission/active', async (req: AuthRequest, res: Response) => {
  try {
    const missions = await gituMissionControl.listActiveMissions(req.userId!);
    res.json({ success: true, missions });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to list active missions', message: error.message });
  }
});

/**
 * GET /mission/:id
 * Get details of a specific mission
 */
router.get('/mission/:id', async (req: AuthRequest, res: Response) => {
  try {
    const mission = await gituMissionControl.getMission(req.params.id);
    if (!mission) return res.status(404).json({ error: 'Mission not found' });

    // Authorization check
    if (mission.userId !== req.userId) return res.status(403).json({ error: 'Access denied' });

    res.json({ success: true, mission });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get mission details', message: error.message });
  }
});

/**
 * GET /mission/:id/detail
 * Get mission plan plus per-task agent status/result (for swarm dashboard)
 */
router.get('/mission/:id/detail', async (req: AuthRequest, res: Response) => {
  try {
    const mission = await gituMissionControl.getMission(req.params.id);
    if (!mission) return res.status(404).json({ error: 'Mission not found' });
    if (mission.userId !== req.userId) return res.status(403).json({ error: 'Access denied' });

    const plan = mission.context?.plan;
    const tasks = Array.isArray(plan?.tasks) ? plan.tasks : [];

    const missionAgents = await gituAgentManager.listAgentsByMission(req.userId!, mission.id);
    const agentsById = new Map(missionAgents.map(a => [a.id, a]));

    const enrichedTasks = tasks.map((t: any) => {
      const agentId = t?.agentId;
      const agent = agentId ? agentsById.get(agentId) : undefined;
      return {
        ...t,
        agent: agent
          ? {
            id: agent.id,
            status: agent.status,
            result: agent.result,
            updatedAt: agent.updatedAt,
          }
          : null,
      };
    });

    res.json({
      success: true,
      mission: {
        ...mission,
        context: {
          ...mission.context,
          plan: plan ? { ...plan, tasks: enrichedTasks } : null,
        },
      }
    });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to get mission detail', message: error.message });
  }
});

/**
 * POST /mission/:id/stop
 * Stop a mission and its agents
 */
router.post('/mission/:id/stop', async (req: AuthRequest, res: Response) => {
  try {
    await gituMissionControl.stopMission(req.params.id, req.userId!);
    res.json({ success: true, message: 'Mission stopped' });
  } catch (error: any) {
    res.status(500).json({ error: 'Failed to stop mission', message: error.message });
  }
});

// ==================== PROACTIVE INSIGHTS ====================

/**
 * GET /insights
 * Get proactive insights for the authenticated user
 */
router.get('/insights', async (req: AuthRequest, res: Response) => {
  try {
    const useCache = req.query.useCache !== 'false';
    const insights = await gituProactiveService.getProactiveInsights(
      req.userId!,
      useCache
    );
    res.json({ success: true, insights });
  } catch (error: any) {
    console.error('[Insights] Error:', error);
    res.status(500).json({
      error: 'Failed to load insights',
      message: error.message
    });
  }
});

/**
 * POST /insights/refresh
 * Force refresh proactive insights (clears cache)
 */
router.post('/insights/refresh', async (req: AuthRequest, res: Response) => {
  try {
    gituProactiveService.clearCache(req.userId!);
    const insights = await gituProactiveService.getProactiveInsights(
      req.userId!,
      false
    );
    res.json({ success: true, insights });
  } catch (error: any) {
    console.error('[Insights Refresh] Error:', error);
    res.status(500).json({
      error: 'Failed to refresh insights',
      message: error.message
    });
  }
});

/**
 * POST /missions/start
 * Start a new Swarm mission via proactive service
 */
router.post('/missions/start', startMissionHandler);

export default router;
