import WebSocket from 'ws';
import { spawn } from 'child_process';
import { ConfigManager } from './config.js';
import chalk from 'chalk';
import { v4 as uuidv4 } from 'uuid';
import readline from 'readline';

export class RemoteTerminalClient {
    private ws: WebSocket | null = null;
    private config: ConfigManager;
    private reconnectAttempts = 0;
    private maxReconnectAttempts = 5;
    private approvalCache = new Map<string, number>();
    private confirmationQueue: Promise<void> = Promise.resolve();

    private isConnected = false;

    constructor(config: ConfigManager) {
        this.config = config;
    }

    async connect() {
        const enabled = Boolean(this.config.get('remoteTerminalEnabled'));
        if (!enabled) return;

        let apiUrl = this.config.get('apiUrl') || 'https://backend.taskiumnetwork.com/api/';
        const token = this.config.get('apiToken');

        if (!token) return;

        let deviceId = this.config.get('deviceId');
        if (!deviceId) {
            deviceId = `cli-${process.platform}-${uuidv4().slice(0, 8)}`;
            this.config.set('deviceId', deviceId);
        }

        const deviceName = 'Gitu CLI (' + process.platform + ')';

        // Convert http/https to ws/wss
        const wsUrl = apiUrl.replace(/^http/, 'ws').replace(/\/api\/$/, '/ws/remote-terminal');

        const url = new URL(wsUrl);
        url.searchParams.append('token', token);
        url.searchParams.append('deviceId', deviceId);
        url.searchParams.append('deviceName', deviceName);

        this.ws = new WebSocket(url.toString());

        this.ws.on('open', () => {
            this.reconnectAttempts = 0;
            // Send Handshake
            this.send({
                type: 'connect',
                payload: {
                    version: '1.0.0', // Should come from package.json in real app
                    capabilities: ['shell.execute'],
                    metadata: {
                        platform: process.platform,
                        arch: process.arch,
                        nodeVersion: process.version
                    }
                }
            });
        });

        this.ws.on('message', (data) => this.handleMessage(data));

        this.ws.on('close', () => {
            this.isConnected = false;
            if (this.reconnectAttempts < this.maxReconnectAttempts) {
                this.reconnectAttempts++;
                setTimeout(() => this.connect(), 1000 * this.reconnectAttempts);
            }
        });

        this.ws.on('error', (err) => {
            // console.error(chalk.red('[Remote Terminal] Connection error:'), err.message);
        });
    }

    private async handleMessage(data: any) {
        try {
            const message = JSON.parse(data.toString());

            if (message.type === 'hello-ok') {
                this.isConnected = true;
                // console.log(chalk.green('[Remote Terminal] Handshake successful'));
                return;
            }

            if (message.type === 'execute') {
                const { id, payload } = message;
                await this.executeCommand(id, payload);
            }
        } catch (err) {
            // console.error('[Remote Terminal] Error handling message:', err);
        }
    }

    private commandFingerprint(payload: any) {
        const command = String(payload?.command || '').trim();
        const args = Array.isArray(payload?.args) ? payload.args.map((a: any) => String(a)) : [];
        const cwd = typeof payload?.cwd === 'string' ? payload.cwd : '';
        return `${command} ${args.join(' ')}`.trim() + `|cwd=${cwd}`;
    }

    private commandText(payload: any) {
        const command = String(payload?.command || '').trim();
        const args = Array.isArray(payload?.args) ? payload.args.map((a: any) => String(a)) : [];
        return [command, ...args].join(' ').trim();
    }

    private matchesAllowlist(commandText: string): boolean {
        const rulesRaw = this.config.get('remoteTerminalAllowedCommands');
        const rules = Array.isArray(rulesRaw) ? rulesRaw.map((r: any) => String(r)) : [];
        if (rules.length === 0) return false;
        if (rules.includes('*')) return true;
        return rules.some(rule => commandText.startsWith(rule));
    }

    private async promptApprove(commandText: string, cwd: string | undefined): Promise<boolean> {
        if (!process.stdin.isTTY) return false;

        return await new Promise<boolean>((resolve) => {
            const rl = readline.createInterface({ input: process.stdin, output: process.stdout });
            const question =
                `\n${chalk.yellow('[Remote Terminal] Approval required')}\n` +
                `${chalk.cyan('Command:')} ${commandText}\n` +
                `${chalk.cyan('CWD:')} ${cwd || process.cwd()}\n` +
                `${chalk.cyan('Allow for')} ${this.config.get('remoteTerminalApprovalTtlSeconds') || 60}s? ${chalk.gray('[y/N] ')}`
            ;

            rl.question(question, (answer) => {
                rl.close();
                const normalized = String(answer || '').trim().toLowerCase();
                resolve(normalized === 'y' || normalized === 'yes');
            });
        });
    }

    private async ensureApproved(payload: any): Promise<boolean> {
        const requireConfirm = Boolean(this.config.get('remoteTerminalRequireConfirm'));
        const commandText = this.commandText(payload);
        const cwd = typeof payload?.cwd === 'string' ? payload.cwd : undefined;

        if (!requireConfirm) return true;

        if (this.matchesAllowlist(commandText)) return true;

        const fingerprint = this.commandFingerprint(payload);
        const now = Date.now();
        const cachedUntil = this.approvalCache.get(fingerprint);
        if (cachedUntil && cachedUntil > now) return true;

        let approved = false;
        this.confirmationQueue = this.confirmationQueue.then(async () => {
            if (approved) return;

            const recheckUntil = this.approvalCache.get(fingerprint);
            if (recheckUntil && recheckUntil > Date.now()) {
                approved = true;
                return;
            }

            approved = await this.promptApprove(commandText, cwd);
            if (approved) {
                const ttlSeconds = Number(this.config.get('remoteTerminalApprovalTtlSeconds') || 60);
                const ttlMs = Number.isFinite(ttlSeconds) && ttlSeconds > 0 ? ttlSeconds * 1000 : 60_000;
                this.approvalCache.set(fingerprint, Date.now() + ttlMs);
            }
        });
        await this.confirmationQueue;

        return approved;
    }

    private async executeCommand(id: string, payload: any) {
        const { command, args = [], cwd } = payload;

        const approved = await this.ensureApproved(payload);
        if (!approved) {
            this.send({
                type: 'execute_result',
                id,
                payload: {
                    success: false,
                    exitCode: 1,
                    stdout: '',
                    stderr: 'Remote command rejected locally',
                    error: 'LOCAL_APPROVAL_REQUIRED'
                }
            });
            return;
        }

        // Use shell: true to support Windows commands and globbing
        const shell = process.platform === 'win32' ? 'powershell.exe' : '/bin/bash';
        const fullCommand = [command, ...args].join(' ');

        const child = spawn(fullCommand, {
            shell: true,
            cwd: cwd || process.cwd(),
            windowsHide: true
        });

        child.stdout.on('data', (chunk) => {
            this.send({
                type: 'execute_output',
                id,
                stream: 'stdout',
                chunk: chunk.toString()
            });
        });

        child.stderr.on('data', (chunk) => {
            this.send({
                type: 'execute_output',
                id,
                stream: 'stderr',
                chunk: chunk.toString()
            });
        });

        child.on('close', (code) => {
            this.send({
                type: 'execute_result',
                id,
                payload: {
                    success: code === 0,
                    exitCode: code,
                    stdout: '', // Chunks were already sent
                    stderr: '',
                    durationMs: 0 // Could track if needed
                }
            });
        });

        child.on('error', (err) => {
            this.send({
                type: 'execute_result',
                id,
                payload: {
                    success: false,
                    exitCode: 1,
                    stdout: '',
                    stderr: err.message,
                    error: err.message
                }
            });
        });
    }

    private send(message: any) {
        if (this.ws && this.ws.readyState === WebSocket.OPEN) {
            this.ws.send(JSON.stringify(message));
        }
    }

    disconnect() {
        if (this.ws) {
            this.ws.removeAllListeners();
            this.ws.close();
        }
    }
}
