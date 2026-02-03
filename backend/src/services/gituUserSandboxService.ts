import crypto from 'node:crypto';
import path from 'node:path';
import { exec } from 'node:child_process';
import util from 'node:util';
import pool from '../config/database.js';

const execAsync = util.promisify(exec);

type SandboxStatus = 'running' | 'stopped' | 'error';

export interface UserSandboxInfo {
  userId: string;
  containerName: string;
  containerId: string | null;
  hostPort: number | null;
  proxyToken: string;
  status: SandboxStatus;
}

export class GituUserSandboxService {
  private readonly imageName = 'gitu-user-sandbox';
  private readonly internalPort = 7337;

  private async ensureTables(): Promise<void> {
    await pool.query(`
      CREATE TABLE IF NOT EXISTS gitu_user_sandboxes (
        user_id UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
        container_name TEXT NOT NULL,
        container_id TEXT,
        host_port INTEGER,
        proxy_token TEXT NOT NULL,
        status TEXT NOT NULL DEFAULT 'stopped',
        last_error TEXT,
        created_at TIMESTAMPTZ DEFAULT NOW(),
        updated_at TIMESTAMPTZ DEFAULT NOW()
      );
    `);
  }

  private buildContainerName(userId: string) {
    return `gitu-sandbox-${userId}`;
  }

  private dockerfileDir() {
    return path.resolve(process.cwd(), 'docker', 'user-sandbox');
  }

  private randomToken() {
    return crypto.randomBytes(32).toString('hex');
  }

  private async ensureImageBuilt(): Promise<void> {
    try {
      await execAsync(`docker image inspect ${this.imageName}`);
    } catch {
      const dir = this.dockerfileDir();
      await execAsync(`docker build -t ${this.imageName} .`, { cwd: dir });
    }
  }

  private async getRunningContainerId(containerName: string): Promise<string | null> {
    try {
      const { stdout } = await execAsync(`docker ps -q -f name=^/${containerName}$`);
      const id = stdout.trim();
      return id.length > 0 ? id : null;
    } catch {
      return null;
    }
  }

  private async getHostPort(containerName: string): Promise<number | null> {
    try {
      const { stdout } = await execAsync(`docker port ${containerName} ${this.internalPort}/tcp`);
      const raw = stdout.trim();
      if (!raw) return null;
      const match = raw.match(/:(\\d+)$/);
      if (!match) return null;
      const port = Number(match[1]);
      return Number.isFinite(port) ? port : null;
    } catch {
      return null;
    }
  }

  async ensureUserSandbox(userId: string): Promise<UserSandboxInfo> {
    await this.ensureTables();

    const containerName = this.buildContainerName(userId);
    const rowRes = await pool.query(
      `SELECT user_id, container_name, container_id, host_port, proxy_token, status
       FROM gitu_user_sandboxes
       WHERE user_id = $1`,
      [userId]
    );

    const existing = rowRes.rows[0] as any | undefined;
    const proxyToken = existing?.proxy_token ? String(existing.proxy_token) : this.randomToken();

    await pool.query(
      `INSERT INTO gitu_user_sandboxes (user_id, container_name, proxy_token, status)
       VALUES ($1,$2,$3,'stopped')
       ON CONFLICT (user_id)
       DO UPDATE SET container_name = EXCLUDED.container_name, proxy_token = EXCLUDED.proxy_token, updated_at = NOW()`,
      [userId, containerName, proxyToken]
    );

    let containerId = await this.getRunningContainerId(containerName);
    let hostPort = containerId ? await this.getHostPort(containerName) : null;
    let status: SandboxStatus = containerId ? 'running' : 'stopped';

    if (!containerId || !hostPort) {
      try {
        await this.ensureImageBuilt();

        const volumeName = `gitu-sandbox-vol-${userId}`;
        const env = [`-e GITU_PROXY_TOKEN=${proxyToken}`, `-e GITU_PROXY_PORT=${this.internalPort}`];
        const runCmd = [
          'docker run -d',
          `--name ${containerName}`,
          '--restart unless-stopped',
          '--memory=1024m',
          '--cpus=1.0',
          '--pids-limit=256',
          '--security-opt=no-new-privileges',
          '--cap-drop=ALL',
          `-p 127.0.0.1::${this.internalPort}`,
          `-v ${volumeName}:/workspace`,
          ...env,
          this.imageName,
        ].join(' ');

        try {
          await execAsync(`docker rm -f ${containerName}`).catch(() => {});
        } catch {}

        const { stdout } = await execAsync(runCmd);
        containerId = stdout.trim() || null;
        hostPort = await this.getHostPort(containerName);
        status = containerId && hostPort ? 'running' : 'error';

        await pool.query(
          `UPDATE gitu_user_sandboxes
           SET container_id = $1, host_port = $2, status = $3, last_error = NULL, updated_at = NOW()
           WHERE user_id = $4`,
          [containerId, hostPort, status, userId]
        );
      } catch (e: any) {
        status = 'error';
        await pool.query(
          `UPDATE gitu_user_sandboxes
           SET status = 'error', last_error = $1, updated_at = NOW()
           WHERE user_id = $2`,
          [e?.message || String(e), userId]
        );
        throw e;
      }
    } else {
      await pool.query(
        `UPDATE gitu_user_sandboxes
         SET container_id = $1, host_port = $2, status = $3, updated_at = NOW()
         WHERE user_id = $4`,
        [containerId, hostPort, status, userId]
      );
    }

    return {
      userId,
      containerName,
      containerId,
      hostPort,
      proxyToken,
      status,
    };
  }

  async stopUserSandbox(userId: string): Promise<void> {
    await this.ensureTables();
    const containerName = this.buildContainerName(userId);
    try {
      await execAsync(`docker rm -f ${containerName}`);
    } catch {}
    await pool.query(
      `UPDATE gitu_user_sandboxes
       SET status = 'stopped', container_id = NULL, host_port = NULL, updated_at = NOW()
       WHERE user_id = $1`,
      [userId]
    );
  }

  async getUserSandbox(userId: string): Promise<UserSandboxInfo | null> {
    await this.ensureTables();
    const res = await pool.query(
      `SELECT user_id, container_name, container_id, host_port, proxy_token, status
       FROM gitu_user_sandboxes
       WHERE user_id = $1`,
      [userId]
    );
    if (res.rows.length === 0) return null;
    const row = res.rows[0] as any;
    return {
      userId: String(row.user_id),
      containerName: String(row.container_name),
      containerId: row.container_id ? String(row.container_id) : null,
      hostPort: row.host_port !== null ? Number(row.host_port) : null,
      proxyToken: String(row.proxy_token),
      status: (row.status as SandboxStatus) || 'stopped',
    };
  }
}

export const gituUserSandboxService = new GituUserSandboxService();

