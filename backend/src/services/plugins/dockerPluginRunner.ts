import fs from 'fs/promises';
import path from 'path';
import { v4 as uuidv4 } from 'uuid';
import { PluginManifest, PluginManifestParser } from './pluginManifest.js';
import { gituShellManager } from '../gituShellManager.js'; // Assuming this exists or we use raw exec
import { exec } from 'child_process';
import util from 'util';

const execAsync = util.promisify(exec);

export interface PluginExecutionResult {
  stdout: string;
  stderr: string;
  exitCode: number;
  durationMs: number;
}

export class DockerPluginRunner {
  private readonly BASE_WORK_DIR = path.resolve(process.cwd(), '.gitu/plugins');

  constructor() {
    // Ensure base directory exists
    fs.mkdir(this.BASE_WORK_DIR, { recursive: true }).catch(console.error);
  }

  /**
   * Run a plugin in a secure container
   */
  async runPlugin(
    pluginId: string, 
    pluginFiles: Record<string, string>, // filename -> content
    args: Record<string, any> = {}
  ): Promise<PluginExecutionResult> {
    
    // 1. Setup workspace
    const runId = uuidv4();
    const workDir = path.join(this.BASE_WORK_DIR, pluginId, runId);
    await fs.mkdir(workDir, { recursive: true });

    try {
      // 2. Write files
      for (const [filename, content] of Object.entries(pluginFiles)) {
        await fs.writeFile(path.join(workDir, filename), content);
      }

      // 3. Parse Manifest
      if (!pluginFiles['plugin.yaml']) {
        throw new Error('Missing plugin.yaml');
      }
      const manifest = PluginManifestParser.parse(pluginFiles['plugin.yaml']);

      // 4. Generate Dockerfile (Strategy B)
      const dockerfileContent = this.generateDockerfile(manifest);
      await fs.writeFile(path.join(workDir, 'Dockerfile'), dockerfileContent);

      // 5. Build Image
      const imageName = `gitu-plugin-${manifest.name}-${runId}`;
      await this.buildImage(workDir, imageName);

      // 6. Run Container
      const result = await this.executeContainer(imageName, manifest, args);

      // 7. Cleanup
      // We don't await cleanup to speed up response, but in prod we might want to
      this.cleanup(workDir, imageName);

      return result;

    } catch (error) {
      // Ensure cleanup happens on error
      this.cleanup(workDir, `gitu-plugin-${pluginId}-${runId}`); // Try to cleanup if image name was generated
      throw error;
    }
  }

  private generateDockerfile(manifest: PluginManifest): string {
    let baseImage = '';
    let installCmd = '';
    let runCmd = '';

    if (manifest.runtime === 'node18') {
      baseImage = 'node:18-slim';
      installCmd = 'RUN if [ -f package.json ]; then npm install; fi';
      runCmd = `CMD ["node", "${manifest.entry}"]`;
    } else if (manifest.runtime === 'python3.11') {
      baseImage = 'python:3.11-slim';
      installCmd = 'RUN if [ -f requirements.txt ]; then pip install --no-cache-dir -r requirements.txt; fi';
      runCmd = `CMD ["python", "${manifest.entry}"]`;
    } else {
      throw new Error(`Unsupported runtime: ${manifest.runtime}`);
    }

    return `
FROM ${baseImage}

# Create app directory
WORKDIR /app

# Copy files
COPY . .

# Install dependencies (during build time)
${installCmd}

# Security: Run as non-root user
RUN groupadd -r gitu && useradd -r -g gitu gitu
USER gitu

# Execution
${runCmd}
`;
  }

  private async buildImage(workDir: string, imageName: string): Promise<void> {
    try {
      await execAsync(`docker build -t ${imageName} .`, { cwd: workDir });
    } catch (e: any) {
      throw new Error(`Docker build failed: ${e.message}\n${e.stderr}`);
    }
  }

  private async executeContainer(
    imageName: string, 
    manifest: PluginManifest, 
    args: Record<string, any>
  ): Promise<PluginExecutionResult> {
    const startTime = Date.now();
    
    // Construct Docker run flags based on permissions
    const flags = [
      '--rm', // Remove container after exit
      '--memory=512m',
      '--cpus=1.0',
      '--security-opt=no-new-privileges',
      '--cap-drop=ALL', // Drop all capabilities
    ];

    // Network permission
    if (manifest.permissions.network) {
      // Allow network but maybe restrict via custom network in future
    } else {
      flags.push('--network=none');
    }

    // Filesystem permission
    if (manifest.permissions.filesystem === 'none') {
      flags.push('--read-only');
      flags.push('--tmpfs /tmp'); // Allow writing to /tmp only
    } else if (manifest.permissions.filesystem === 'read-only') {
        flags.push('--read-only');
    }
    // 'read-write' allows default container FS behavior (ephemeral)

    // Pass args as Environment Variable or JSON file?
    // Let's pass as ENV var 'PLUGIN_ARGS'
    const envArgs = JSON.stringify(args);
    // Escaping might be tricky, passing as base64 is safer
    const envArgsB64 = Buffer.from(envArgs).toString('base64');
    flags.push(`-e PLUGIN_ARGS_B64=${envArgsB64}`);

    const command = `docker run ${flags.join(' ')} ${imageName}`;

    try {
      const { stdout, stderr } = await execAsync(command, { 
        timeout: 30000 // 30s hard timeout
      });
      
      return {
        stdout,
        stderr,
        exitCode: 0,
        durationMs: Date.now() - startTime
      };
    } catch (e: any) {
      return {
        stdout: e.stdout || '',
        stderr: e.stderr || e.message,
        exitCode: e.code || 1,
        durationMs: Date.now() - startTime
      };
    }
  }

  private async cleanup(workDir: string, imageName: string): Promise<void> {
    try {
      // Remove image
      await execAsync(`docker rmi ${imageName}`).catch(() => {}); // Ignore if image doesn't exist
      // Remove files
      await fs.rm(workDir, { recursive: true, force: true });
    } catch (e) {
      console.error(`Cleanup failed for ${workDir}`, e);
    }
  }
}

export const dockerPluginRunner = new DockerPluginRunner();
