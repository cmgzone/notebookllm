import path from 'path';
import fs from 'fs/promises';
import fsSync from 'fs';
import { gituMCPHub, MCPTool, MCPContext } from './gituMCPHub.js';
import { gituShellManager } from './gituShellManager.js';
import { gituPermissionManager } from './gituPermissionManager.js';
import { whatsappAdapter } from '../adapters/whatsappAdapter.js';
import { telegramAdapter } from '../adapters/telegramAdapter.js';
import pool from '../config/database.js';

type Platform = 'whatsapp' | 'telegram';

const DEFAULT_TIMEOUT_MS = 10 * 60_000;
const DEFAULT_PERMISSION_DAYS = 30;

const codecExtensions: Record<string, string> = {
  h264: 'mp4',
  h265: 'mp4',
  vp8: 'webm',
  vp9: 'webm',
  prores: 'mov',
  gif: 'gif',
};

async function getLinkedIdentity(userId: string, platform: Platform): Promise<string | null> {
  const res = await pool.query(
    `SELECT platform_user_id FROM gitu_linked_accounts
     WHERE user_id = $1 AND platform = $2 AND status = 'active'`,
    [userId, platform]
  );
  return res.rows.length > 0 ? res.rows[0].platform_user_id : null;
}

async function getActiveMessagingPlatforms(userId: string): Promise<Platform[]> {
  const res = await pool.query(
    `SELECT platform
     FROM gitu_linked_accounts
     WHERE user_id = $1
       AND platform IN ('whatsapp', 'telegram')
       AND status = 'active'`,
    [userId]
  );
  return res.rows.map((row: any) => row.platform as Platform);
}

function normalizePlatform(raw?: string | null): Platform | undefined {
  if (!raw) return undefined;
  const value = String(raw).trim().toLowerCase();
  if (value === 'whatsapp' || value === 'wa') return 'whatsapp';
  if (value === 'telegram' || value === 'tg') return 'telegram';
  return undefined;
}

function inferPlatformFromRecipient(recipient?: string): Platform | undefined {
  if (!recipient) return undefined;
  const value = recipient.trim().toLowerCase();
  if (value.startsWith('tg:') || value.startsWith('telegram:')) return 'telegram';
  if (value.startsWith('wa:') || value.startsWith('whatsapp:')) return 'whatsapp';
  if (value.includes('@s.whatsapp.net') || value.includes('@g.us')) return 'whatsapp';
  return undefined;
}

function stripRecipientPrefix(recipient: string, prefixes: string[]): string {
  const lower = recipient.trim().toLowerCase();
  for (const prefix of prefixes) {
    if (lower.startsWith(prefix)) {
      return recipient.trim().slice(prefix.length).trim();
    }
  }
  return recipient.trim();
}

async function resolveEntry(projectPath: string, entry?: string): Promise<string | null> {
  if (entry && entry.trim().length > 0) {
    return path.isAbsolute(entry) ? entry : path.join(projectPath, entry);
  }

  const candidates = [
    'src/index.tsx',
    'src/index.ts',
    'src/index.jsx',
    'src/index.js',
    'remotion/index.tsx',
    'remotion/index.ts',
  ];

  for (const candidate of candidates) {
    const full = path.join(projectPath, candidate);
    if (fsSync.existsSync(full)) {
      return full;
    }
  }

  return null;
}

async function sendVideoToPlatform(
  context: MCPContext,
  platform: Platform,
  recipient: string,
  filePath: string,
  caption?: string
) {
  const identity = await getLinkedIdentity(context.userId, platform);
  if (!identity) {
    throw new Error(
      `No linked ${platform} account found. Link it in the app (Settings → Gitu → Linked Accounts), then retry.`
    );
  }

  let targetId = identity;
  if (recipient !== 'self') {
    if (platform === 'whatsapp') {
      const cleaned = stripRecipientPrefix(recipient, ['wa:', 'whatsapp:']);
      if (cleaned.includes('@')) {
        targetId = cleaned;
      } else {
        const contacts = await whatsappAdapter.searchContacts(cleaned);
        if (contacts.length > 0) {
          targetId = contacts[0].id;
        } else {
          targetId = `${cleaned.replace(/\D/g, '')}@s.whatsapp.net`;
        }
      }
    } else {
      const cleaned = stripRecipientPrefix(recipient, ['tg:', 'telegram:']);
      targetId = cleaned;
    }
  }

  const videoBuffer = await fs.readFile(filePath);
  const baseName = path.basename(filePath);

  if (platform === 'whatsapp') {
    await whatsappAdapter.sendMessage(targetId, {
      video: videoBuffer,
      caption,
    });
  } else {
    await telegramAdapter.sendMessage(targetId, {
      video: videoBuffer,
      caption,
    } as any);
  }
}

async function requestRemotionPermission(userId: string, projectPath: string) {
  const expiresAt = new Date(Date.now() + DEFAULT_PERMISSION_DAYS * 24 * 60 * 60 * 1000);
  await gituPermissionManager.requestPermission(
    userId,
    {
      resource: 'shell',
      actions: ['execute'],
      scope: {
        allowedCommands: ['npx remotion', 'npx remotion render'],
        allowedPaths: [projectPath],
        customScope: { allowUnsandboxed: true },
      },
      expiresAt,
    },
    'Render a Remotion video'
  );
}

const renderRemotionTool: MCPTool = {
  name: 'render_remotion_video',
  description:
    'Render a Remotion composition and optionally send the video via WhatsApp or Telegram.',
  schema: {
    type: 'object',
    properties: {
      projectPath: {
        type: 'string',
        description: 'Absolute path to the Remotion project. Defaults to GITU_REMOTION_PROJECT_PATH.',
      },
      entry: {
        type: 'string',
        description: 'Optional entry file (e.g. src/index.tsx). If omitted, common defaults are detected.',
      },
      composition: {
        type: 'string',
        description: 'Composition ID to render.',
        default: 'Main',
      },
      inputProps: {
        type: 'object',
        description: 'Props passed to the composition as JSON.',
      },
      outputDir: {
        type: 'string',
        description: 'Output directory for rendered video.',
      },
      outputName: {
        type: 'string',
        description: 'Output filename (extension optional).',
      },
      codec: {
        type: 'string',
        description: 'Remotion codec (h264, h265, vp8, vp9, prores, gif).',
        default: 'h264',
      },
      fps: { type: 'number', description: 'Frames per second.' },
      width: { type: 'number', description: 'Width override.' },
      height: { type: 'number', description: 'Height override.' },
      durationInFrames: { type: 'number', description: 'Duration override.' },
      concurrency: { type: 'number', description: 'Render concurrency.' },
      timeoutMs: { type: 'number', description: 'Render timeout in ms.', default: DEFAULT_TIMEOUT_MS },
      sandboxed: {
        type: 'boolean',
        description: 'Run in sandbox (default false). Unsandboxed requires a connected remote terminal.',
        default: false,
      },
      send: {
        type: 'boolean',
        description: 'Send the rendered video to a messaging platform.',
        default: true,
      },
      platform: {
        type: 'string',
        description: 'Platform to send to (whatsapp or telegram). Optional if only one is linked.',
      },
      recipient: {
        type: 'string',
        description: 'Recipient (name, number, or "self"). Prefix with wa:/tg: to disambiguate.',
        default: 'self',
      },
      caption: {
        type: 'string',
        description: 'Optional caption to include with the video.',
      },
      cleanup: {
        type: 'boolean',
        description: 'Delete the rendered file after sending.',
        default: false,
      },
    },
    required: ['composition'],
  },
  handler: async (args: any, context: MCPContext) => {
    const {
      projectPath,
      entry,
      composition = 'Main',
      inputProps,
      outputDir,
      outputName,
      codec = 'h264',
      fps,
      width,
      height,
      durationInFrames,
      concurrency,
      timeoutMs = DEFAULT_TIMEOUT_MS,
      sandboxed = false,
      send = true,
      platform,
      recipient = 'self',
      caption,
      cleanup = false,
    } = args;

    const resolvedProjectPath =
      (typeof projectPath === 'string' && projectPath.trim().length > 0
        ? projectPath.trim()
        : (process.env.GITU_REMOTION_PROJECT_PATH || '').trim()) || '';

    if (!resolvedProjectPath) {
      throw new Error(
        'Remotion projectPath is required. Provide projectPath or set GITU_REMOTION_PROJECT_PATH.'
      );
    }

    const resolvedEntry = await resolveEntry(resolvedProjectPath, entry);
    const outputExtension = codecExtensions[codec] || 'mp4';
    const outputBase =
      typeof outputName === 'string' && outputName.trim().length > 0
        ? outputName.trim()
        : `remotion-${composition}-${Date.now()}`;
    const normalizedOutputName = outputBase.endsWith(`.${outputExtension}`)
      ? outputBase
      : `${outputBase}.${outputExtension}`;

    const resolvedOutputDir =
      typeof outputDir === 'string' && outputDir.trim().length > 0
        ? outputDir.trim()
        : path.join(resolvedProjectPath, 'out');

    await fs.mkdir(resolvedOutputDir, { recursive: true });
    const outputPath = path.isAbsolute(normalizedOutputName)
      ? normalizedOutputName
      : path.join(resolvedOutputDir, normalizedOutputName);

    const commandArgs: string[] = ['remotion', 'render'];
    if (resolvedEntry) {
      commandArgs.push(resolvedEntry);
    }
    commandArgs.push(composition, outputPath);

    if (inputProps && Object.keys(inputProps).length > 0) {
      commandArgs.push('--props', JSON.stringify(inputProps));
    }
    if (codec) commandArgs.push('--codec', String(codec));
    if (fps) commandArgs.push('--fps', String(fps));
    if (width) commandArgs.push('--width', String(width));
    if (height) commandArgs.push('--height', String(height));
    if (durationInFrames) commandArgs.push('--duration-in-frames', String(durationInFrames));
    if (concurrency) commandArgs.push('--concurrency', String(concurrency));

    const result = await gituShellManager.execute(context.userId, {
      command: 'npx',
      args: commandArgs,
      cwd: resolvedProjectPath,
      timeoutMs,
      sandboxed,
    });

    if (!result.success) {
      const error = result.error || result.stderr || 'Render failed';
      if (error === 'SHELL_PERMISSION_DENIED') {
        await requestRemotionPermission(context.userId, resolvedProjectPath);
        throw new Error(
          'Shell access is not approved. I created a permission request; approve it in Settings → Gitu → Permissions, then retry.'
        );
      }
      if (error === 'REMOTE_EXECUTION_NOT_ALLOWED' || error === 'UNSANDBOXED_MODE_NOT_ALLOWED') {
        await requestRemotionPermission(context.userId, resolvedProjectPath);
        throw new Error(
          'Unsandboxed render not allowed. I created a permission request; approve it in Settings → Gitu → Permissions, then retry.'
        );
      }
      if (error === 'SHELL_CWD_NOT_ALLOWED') {
        await requestRemotionPermission(context.userId, resolvedProjectPath);
        throw new Error(
          'Project path not allowed by current shell permissions. I created a request with the project path; approve it and retry.'
        );
      }
      throw new Error(`Remotion render failed: ${error}`);
    }

    if (!fsSync.existsSync(outputPath)) {
      throw new Error(
        'Render completed but output file was not found. Check outputDir/outputName or Remotion logs.'
      );
    }

    let sent = false;
    let resolvedPlatform: Platform | undefined = normalizePlatform(platform) || normalizePlatform(context.platform) || inferPlatformFromRecipient(recipient);

    if (send) {
      if (!resolvedPlatform) {
        const active = await getActiveMessagingPlatforms(context.userId);
        if (active.length === 1) {
          resolvedPlatform = active[0];
        }
      }
      if (!resolvedPlatform) {
        throw new Error(
          'Platform is required to send the video. Specify "whatsapp" or "telegram", or link exactly one of them.'
        );
      }

      await sendVideoToPlatform(
        context,
        resolvedPlatform,
        recipient,
        outputPath,
        caption || `Remotion render: ${composition}`
      );
      sent = true;
    }

    if (cleanup) {
      await fs.rm(outputPath, { force: true });
    }

    return {
      success: true,
      outputPath,
      sent,
      platform: resolvedPlatform,
      recipient,
      stdout: result.stdout,
      stderr: result.stderr,
      durationMs: result.durationMs,
      mode: result.mode,
    };
  },
};

export function registerRemotionTools() {
  gituMCPHub.registerTool(renderRemotionTool);
  console.log('[RemotionMCPTools] Registered render_remotion_video tool');
}
