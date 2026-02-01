import crypto from 'crypto';
import { gituAIRouter } from './gituAIRouter.js';
import { gituMissionControl, type Mission } from './gituMissionControl.js';
import { gituPermissionManager } from './gituPermissionManager.js';
import { gituShellManager } from './gituShellManager.js';
import { readFile, writeFile } from './gituFileManager.js';
import { gituEvaluationService } from './gituEvaluationService.js';

export interface ImprovementCommandSpec {
  command: string;
  args?: string[];
  timeoutMs?: number;
  sandboxed?: boolean;
}

export interface ImprovementFileProposal {
  path: string;
  expectedOldSha256: string;
  newContent: string;
  reason?: string;
}

export interface ImprovementProposal {
  summary: string;
  risks?: string[];
  files: ImprovementFileProposal[];
  verification?: {
    commands: ImprovementCommandSpec[];
  };
}

export interface StartSelfImprovementInput {
  userId: string;
  objective: string;
  targetPaths: string[];
  verificationCommands?: ImprovementCommandSpec[];
}

const MAX_TARGET_PATHS = 10;
const MAX_PROPOSAL_FILES = 20;
const MAX_FILE_BYTES = 80_000;
const MAX_TOTAL_BYTES = 250_000;
const MAX_VERIFICATION_COMMANDS = 6;
const ALLOWED_VERIFICATION_COMMANDS = new Set(['npm', 'pnpm', 'yarn', 'node']);

const normalizeScopePath = (p: string) =>
  p
    .trim()
    .replace(/^(\.\/|\.\\)+/, '')
    .replace(/\\/g, '/')
    .replace(/\/+/g, '/')
    .replace(/\/$/, '');

function sha256(input: string) {
  return crypto.createHash('sha256').update(input, 'utf8').digest('hex');
}

function tryExtractJson(content: string): any | null {
  const blockMatch = content.match(/```json\s*\n?([\s\S]*?)\n?```/i);
  const jsonCandidate = (blockMatch?.[1] || '').trim();
  const candidate = jsonCandidate || (content.match(/\{[\s\S]*\}/)?.[0] ?? '').trim();
  if (!candidate) return null;
  try {
    return JSON.parse(candidate);
  } catch {
    return null;
  }
}

class GituSelfImprovementService {
  async startSelfImprovement(input: StartSelfImprovementInput): Promise<{
    mission: Mission;
    proposal?: ImprovementProposal;
    permissionRequests?: { filesRead?: string; filesWrite?: string; shellExecute?: string };
  }> {
    const mission = await gituMissionControl.createMission(
      input.userId,
      `Self Improvement: ${input.objective.substring(0, 40)}`,
      input.objective
    );

    const normalizedTargets = Array.from(new Set((input.targetPaths || []).map(normalizeScopePath).filter(Boolean)));
    if (normalizedTargets.length === 0) {
      await gituMissionControl.updateMissionState(mission.id, {
        status: 'failed',
        logEntry: 'Self-improvement mission requires at least one target path.'
      });
      return { mission: (await gituMissionControl.getMission(mission.id)) as Mission };
    }
    if (normalizedTargets.length > MAX_TARGET_PATHS) {
      await gituMissionControl.updateMissionState(mission.id, {
        status: 'failed',
        logEntry: `Too many target paths for self-improvement (max ${MAX_TARGET_PATHS}).`
      });
      return { mission: (await gituMissionControl.getMission(mission.id)) as Mission };
    }

    await gituMissionControl.updateMissionState(mission.id, {
      status: 'active',
      contextUpdates: {
        missionType: 'self_improvement',
        selfImprovement: {
          targetPaths: normalizedTargets,
          status: 'starting',
          createdAt: new Date().toISOString()
        }
      },
      logEntry: `Self-improvement mission created with ${normalizedTargets.length} target path(s).`
    });

    const permissionRequests: { filesRead?: string; filesWrite?: string; shellExecute?: string } = {};

    const hasFilesRead = await this.checkFilesPermission(input.userId, 'read', normalizedTargets);
    if (!hasFilesRead) {
      const req = await gituPermissionManager.requestPermission(
        input.userId,
        {
          resource: 'files',
          actions: ['read'],
          scope: { allowedPaths: normalizedTargets }
        },
        `Self-improvement needs read access to: ${normalizedTargets.join(', ')}`
      );
      permissionRequests.filesRead = req.id;
      const existing = await this.getSelfImprovementContext(mission.id);

      await gituMissionControl.updateMissionState(mission.id, {
        status: 'paused',
        contextUpdates: {
          selfImprovement: {
            ...existing,
            targetPaths: normalizedTargets,
            status: 'waiting_for_files_read_permission',
            permissionRequests
          }
        },
        logEntry: 'Waiting for file read permission to generate a proposal.'
      });

      return { mission: (await gituMissionControl.getMission(mission.id)) as Mission, permissionRequests };
    }

    const proposal = await this.generateProposal(input.userId, mission.id, input.objective, normalizedTargets, input.verificationCommands);
    const existingAfterProposal = await this.getSelfImprovementContext(mission.id);

    await gituMissionControl.updateMissionState(mission.id, {
      status: 'paused',
      artifacts: {
        selfImprovementProposal: proposal
      },
      contextUpdates: {
        selfImprovement: {
          ...existingAfterProposal,
          targetPaths: normalizedTargets,
          status: 'proposal_ready'
        }
      },
      logEntry: `Self-improvement proposal generated (${proposal.files.length} file(s)): ${proposal.files.slice(0, 5).map(f => f.path).join(', ')}${proposal.files.length > 5 ? '…' : ''}`
    });

    const shellCommands = proposal.verification?.commands ?? [];
    if (shellCommands.length > 0) {
      if (shellCommands.length > MAX_VERIFICATION_COMMANDS) {
        await gituMissionControl.updateMissionState(mission.id, {
          status: 'failed',
          logEntry: `Too many verification commands in proposal (max ${MAX_VERIFICATION_COMMANDS}).`
        });
        return { mission: (await gituMissionControl.getMission(mission.id)) as Mission, proposal, permissionRequests };
      }

      const shellAllowed = await gituPermissionManager.checkPermission(input.userId, {
        resource: 'shell',
        action: 'execute',
        scope: { command: 'npm' }
      });

      if (!shellAllowed) {
        const req = await gituPermissionManager.requestPermission(
          input.userId,
          {
            resource: 'shell',
            actions: ['execute'],
            scope: { allowedCommands: ['npm', 'pnpm', 'yarn', 'node'] }
          },
          'Self-improvement verification needs sandboxed shell execution (npm/pnpm/yarn).'
        );
        permissionRequests.shellExecute = req.id;
        const existingWaitingShell = await this.getSelfImprovementContext(mission.id);

        await gituMissionControl.updateMissionState(mission.id, {
          contextUpdates: {
            selfImprovement: {
              ...existingWaitingShell,
              targetPaths: normalizedTargets,
              status: 'waiting_for_shell_permission',
              permissionRequests
            }
          },
          logEntry: 'Waiting for shell permission to run verification commands.'
        });
      } else {
        await this.verifyProposal(input.userId, mission.id, shellCommands);
      }
    }

    return { mission: (await gituMissionControl.getMission(mission.id)) as Mission, proposal, permissionRequests };
  }

  async runVerification(userId: string, missionId: string): Promise<Mission> {
    const mission = await gituMissionControl.getMission(missionId);
    if (!mission) throw new Error('Mission not found');
    if (mission.userId !== userId) throw new Error('Access denied');

    const missionType = mission.context?.missionType;
    if (missionType !== 'self_improvement') throw new Error('Mission is not a self-improvement mission');

    const proposal = mission.artifacts?.selfImprovementProposal as ImprovementProposal | undefined;
    const commands = proposal?.verification?.commands ?? [];
    if (commands.length === 0) throw new Error('No verification commands present in proposal');
    if (commands.length > MAX_VERIFICATION_COMMANDS) throw new Error(`Too many verification commands (max ${MAX_VERIFICATION_COMMANDS})`);

    for (const c of commands) {
      if (!ALLOWED_VERIFICATION_COMMANDS.has(String(c.command || '').trim())) {
        throw new Error(`Verification command not allowed: ${String(c.command || '')}`);
      }
    }

    const shellAllowed = await gituPermissionManager.checkPermission(userId, {
      resource: 'shell',
      action: 'execute',
      scope: { command: commands[0]?.command || 'npm' }
    });
    if (!shellAllowed) {
      const req = await gituPermissionManager.requestPermission(
        userId,
        {
          resource: 'shell',
          actions: ['execute'],
          scope: { allowedCommands: ['npm', 'pnpm', 'yarn', 'node'] }
        },
        'Self-improvement verification needs sandboxed shell execution (npm/pnpm/yarn).'
      );

      const existing = await this.getSelfImprovementContext(missionId);
      await gituMissionControl.updateMissionState(missionId, {
        status: 'paused',
        contextUpdates: {
          selfImprovement: {
            ...existing,
            status: 'waiting_for_shell_permission',
            permissionRequests: {
              ...(existing?.permissionRequests || {}),
              shellExecute: req.id
            }
          }
        },
        logEntry: 'Waiting for shell permission to run verification commands.'
      });

      return (await gituMissionControl.getMission(missionId)) as Mission;
    }

    await this.verifyProposal(userId, missionId, commands);
    return (await gituMissionControl.getMission(missionId)) as Mission;
  }

  async applyProposal(userId: string, missionId: string): Promise<Mission> {
    const mission = await gituMissionControl.getMission(missionId);
    if (!mission) throw new Error('Mission not found');
    if (mission.userId !== userId) throw new Error('Access denied');

    const missionType = mission.context?.missionType;
    if (missionType !== 'self_improvement') throw new Error('Mission is not a self-improvement mission');

    const proposal = mission.artifacts?.selfImprovementProposal as ImprovementProposal | undefined;
    if (!proposal || !Array.isArray(proposal.files) || proposal.files.length === 0) {
      throw new Error('No proposal found to apply');
    }
    if (proposal.files.length > MAX_PROPOSAL_FILES) {
      throw new Error(`Too many proposed files to apply (max ${MAX_PROPOSAL_FILES})`);
    }

    const verification = mission.artifacts?.selfImprovementVerification;
    if (!verification || verification?.passed !== true) {
      throw new Error('Verification not passed; refusing to apply proposal');
    }

    const normalizedTargets = Array.isArray(mission.context?.selfImprovement?.targetPaths)
      ? mission.context.selfImprovement.targetPaths.map(normalizeScopePath)
      : [];
    const hasFilesWrite = await this.checkFilesPermission(userId, 'write', normalizedTargets);
    if (!hasFilesWrite) {
      const req = await gituPermissionManager.requestPermission(
        userId,
        {
          resource: 'files',
          actions: ['write'],
          scope: { allowedPaths: normalizedTargets }
        },
        `Self-improvement apply needs write access to: ${normalizedTargets.join(', ')}`
      );

      const existing = await this.getSelfImprovementContext(missionId);
      await gituMissionControl.updateMissionState(missionId, {
        status: 'paused',
        contextUpdates: {
          selfImprovement: {
            ...existing,
            targetPaths: normalizedTargets,
            status: 'waiting_for_files_write_permission',
            permissionRequests: {
              ...(existing?.permissionRequests || {}),
              filesWrite: req.id
            }
          }
        },
        logEntry: 'Waiting for file write permission to apply proposal.'
      });

      return (await gituMissionControl.getMission(missionId)) as Mission;
    }

    const applyResults: Array<{ path: string; applied: boolean; reason?: string }> = [];

    for (const file of proposal.files) {
      const normalizedPath = normalizeScopePath(file.path);
      const ok = await gituPermissionManager.checkPermission(userId, {
        resource: 'files',
        action: 'write',
        scope: { path: normalizedPath }
      });
      if (!ok) {
        applyResults.push({ path: normalizedPath, applied: false, reason: 'FILE_ACCESS_DENIED' });
        continue;
      }

      const current = await readFile(userId, normalizedPath);
      const currentHash = sha256(current);
      if (currentHash !== file.expectedOldSha256) {
        applyResults.push({ path: normalizedPath, applied: false, reason: 'EXPECTED_OLD_HASH_MISMATCH' });
        continue;
      }

      if (Buffer.byteLength(file.newContent || '', 'utf8') > MAX_FILE_BYTES) {
        applyResults.push({ path: normalizedPath, applied: false, reason: 'NEW_CONTENT_TOO_LARGE' });
        continue;
      }

      await writeFile(userId, normalizedPath, file.newContent);
      applyResults.push({ path: normalizedPath, applied: true });
    }

    const allApplied = applyResults.every(r => r.applied);

    await gituMissionControl.updateMissionState(missionId, {
      status: allApplied ? 'completed' : 'failed',
      artifacts: {
        selfImprovementApplyResults: applyResults,
        selfImprovementAppliedAt: new Date().toISOString()
      },
      logEntry: allApplied ? 'Self-improvement proposal applied.' : 'Self-improvement proposal failed to apply.'
    });

    await gituEvaluationService.createEvaluation({
      userId,
      targetType: 'mission',
      missionId,
      evaluator: 'system',
      passed: allApplied,
      score: allApplied ? 1 : 0,
      criteria: {
        kind: 'self_improvement_apply',
        allApplied,
        results: applyResults
      }
    });

    return (await gituMissionControl.getMission(missionId)) as Mission;
  }

  private async checkFilesPermission(userId: string, action: 'read' | 'write', allowedPaths: string[]): Promise<boolean> {
    if (!Array.isArray(allowedPaths) || allowedPaths.length === 0) return false;
    for (const p of allowedPaths) {
      const ok = await gituPermissionManager.checkPermission(userId, {
        resource: 'files',
        action,
        scope: { path: normalizeScopePath(p) }
      });
      if (!ok) return false;
    }
    return true;
  }

  private async generateProposal(
    userId: string,
    missionId: string,
    objective: string,
    targetPaths: string[],
    verificationCommands?: ImprovementCommandSpec[]
  ): Promise<ImprovementProposal> {
    const fileContexts: Array<{ path: string; sha256: string; content: string }> = [];
    let totalBytes = 0;

    for (const p of targetPaths) {
      const content = await readFile(userId, p);
      const bytes = Buffer.byteLength(content, 'utf8');
      totalBytes += bytes;
      if (bytes > MAX_FILE_BYTES) {
        await gituMissionControl.updateMissionState(missionId, {
          status: 'failed',
          logEntry: `Target file too large for self-improvement: ${p} (${bytes} bytes, max ${MAX_FILE_BYTES})`
        });
        throw new Error('Target file too large');
      }
      if (totalBytes > MAX_TOTAL_BYTES) {
        await gituMissionControl.updateMissionState(missionId, {
          status: 'failed',
          logEntry: `Total target size too large for self-improvement (max ${MAX_TOTAL_BYTES} bytes).`
        });
        throw new Error('Total target size too large');
      }
      fileContexts.push({ path: p, sha256: sha256(content), content });
    }

    const commandHints = Array.isArray(verificationCommands) && verificationCommands.length > 0
      ? verificationCommands
      : [
        { command: 'npm', args: ['run', 'lint'], timeoutMs: 300000, sandboxed: true },
        { command: 'npm', args: ['test'], timeoutMs: 300000, sandboxed: true }
      ];

    const prompt = `
OBJECTIVE:
${objective}

You are a self-improvement agent for this repository.
You must produce a safe, minimal set of file changes that improve correctness and stability.

TARGET FILES (read-only snapshots):
${fileContexts.map(f => `\n---\nPATH: ${f.path}\nEXPECTED_OLD_SHA256: ${f.sha256}\nCONTENT:\n${f.content}\n`).join('\n')}

REQUIREMENTS:
- Return ONLY valid JSON inside a \`\`\`json\`\`\` code block.
- Propose edits ONLY to the provided target files/paths.
- For every changed file, include: path, expectedOldSha256 (exactly as provided), and full newContent.
- No hard-coded secrets. No fake data. No placeholders.

JSON SHAPE:
{
  "summary": "string",
  "risks": ["string"],
  "files": [
    { "path": "string", "expectedOldSha256": "string", "newContent": "string", "reason": "string" }
  ],
  "verification": {
    "commands": [
      { "command": "string", "args": ["string"], "timeoutMs": 300000, "sandboxed": true }
    ]
  }
}

Suggested verification commands (adjust if needed):
${JSON.stringify({ commands: commandHints }, null, 2)}
`;

    const response = await gituAIRouter.route({
      userId,
      prompt,
      taskType: 'analysis',
      platform: 'terminal'
    });

    const parsed = tryExtractJson(response.content);
    if (!parsed) {
      await gituMissionControl.updateMissionState(missionId, {
        status: 'failed',
        logEntry: 'Failed to parse improvement proposal JSON from AI.'
      });
      throw new Error('AI proposal did not return valid JSON');
    }

    const proposal: ImprovementProposal = {
      summary: String(parsed.summary || '').trim(),
      risks: Array.isArray(parsed.risks) ? parsed.risks.map((r: any) => String(r)).filter(Boolean) : [],
      files: Array.isArray(parsed.files)
        ? parsed.files
          .map((f: any) => ({
            path: normalizeScopePath(String(f.path || '')),
            expectedOldSha256: String(f.expectedOldSha256 || ''),
            newContent: String(f.newContent || ''),
            reason: typeof f.reason === 'string' ? f.reason : undefined,
          }))
          .filter((f: any) => f.path && f.expectedOldSha256 && typeof f.newContent === 'string')
        : [],
      verification: parsed.verification?.commands
        ? {
          commands: (Array.isArray(parsed.verification.commands) ? parsed.verification.commands : []).map((c: any) => ({
            command: String(c.command || '').trim(),
            args: Array.isArray(c.args) ? c.args.map((a: any) => String(a)) : [],
            timeoutMs: typeof c.timeoutMs === 'number' ? c.timeoutMs : undefined,
            sandboxed: true
          })).filter((c: any) => c.command)
        }
        : undefined
    };

    if (!proposal.summary || proposal.files.length === 0) {
      await gituMissionControl.updateMissionState(missionId, {
        status: 'failed',
        logEntry: 'AI proposal JSON was missing summary or file updates.'
      });
      throw new Error('AI proposal missing summary or files');
    }

    if (proposal.files.length > MAX_PROPOSAL_FILES) {
      await gituMissionControl.updateMissionState(missionId, {
        status: 'failed',
        logEntry: `AI proposal included too many files (max ${MAX_PROPOSAL_FILES}).`
      });
      throw new Error('AI proposal too many files');
    }

    const cmds = proposal.verification?.commands ?? [];
    if (cmds.length > MAX_VERIFICATION_COMMANDS) {
      await gituMissionControl.updateMissionState(missionId, {
        status: 'failed',
        logEntry: `AI proposal included too many verification commands (max ${MAX_VERIFICATION_COMMANDS}).`
      });
      throw new Error('AI proposal too many verification commands');
    }
    for (const c of cmds) {
      if (!ALLOWED_VERIFICATION_COMMANDS.has(String(c.command || '').trim())) {
        await gituMissionControl.updateMissionState(missionId, {
          status: 'failed',
          logEntry: `AI proposal included disallowed verification command: ${String(c.command || '')}`
        });
        throw new Error('AI proposal included disallowed verification command');
      }
    }

    const allowed = new Set(targetPaths.map(normalizeScopePath));
    for (const f of proposal.files) {
      const inScope = Array.from(allowed).some(ap => f.path === ap || f.path.startsWith(`${ap}/`));
      if (!inScope) {
        await gituMissionControl.updateMissionState(missionId, {
          status: 'failed',
          logEntry: `AI proposal attempted to modify out-of-scope file: ${f.path}`
        });
        throw new Error('AI proposal attempted out-of-scope modification');
      }
    }

    return proposal;
  }

  private async verifyProposal(userId: string, missionId: string, commands: ImprovementCommandSpec[]): Promise<void> {
    const results: Array<any> = [];
    let passed = true;

    for (const c of commands) {
      const cmd = String(c.command || '').trim();
      if (!ALLOWED_VERIFICATION_COMMANDS.has(cmd)) {
        throw new Error(`Verification command not allowed: ${cmd}`);
      }
      const result = await gituShellManager.execute(userId, {
        command: cmd,
        args: c.args,
        timeoutMs: c.timeoutMs,
        sandboxed: true
      });
      results.push(result);
      if (!result.success) passed = false;
    }

    await gituMissionControl.updateMissionState(missionId, {
      artifacts: {
        selfImprovementVerification: {
          passed,
          results,
          verifiedAt: new Date().toISOString()
        }
      },
      contextUpdates: {
        selfImprovement: await this.mergeSelfImprovementContext(missionId, {
          status: passed ? 'verification_passed' : 'verification_failed'
        })
      },
      logEntry: passed ? 'Self-improvement verification passed.' : 'Self-improvement verification failed.'
    });

    await gituEvaluationService.createEvaluation({
      userId,
      targetType: 'mission',
      missionId,
      evaluator: 'system',
      passed,
      score: passed ? 1 : 0,
      criteria: {
        kind: 'self_improvement_verification',
        commands
      },
      notes: passed ? 'All verification commands succeeded.' : 'One or more verification commands failed.'
    });
  }

  private async getSelfImprovementContext(missionId: string): Promise<Record<string, any>> {
    const mission = await gituMissionControl.getMission(missionId);
    const ctx = mission?.context?.selfImprovement;
    if (!ctx || typeof ctx !== 'object') return {};
    return ctx as Record<string, any>;
  }

  private async mergeSelfImprovementContext(missionId: string, updates: Record<string, any>): Promise<Record<string, any>> {
    const existing = await this.getSelfImprovementContext(missionId);
    return { ...existing, ...updates };
  }
}

export const gituSelfImprovementService = new GituSelfImprovementService();
