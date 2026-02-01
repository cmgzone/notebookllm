import WebSocket from 'ws';
import { spawn } from 'child_process';
import { ConfigManager } from './config.js';
import chalk from 'chalk';

export class RemoteTerminalClient {
    private ws: WebSocket | null = null;
    private config: ConfigManager;
    private reconnectAttempts = 0;
    private maxReconnectAttempts = 5;

    constructor(config: ConfigManager) {
        this.config = config;
    }

    async connect() {
        let apiUrl = this.config.get('apiUrl') || 'https://backend.taskiumnetwork.com/api/';
        const token = this.config.get('apiToken');

        if (!token) return;

        // Convert http/https to ws/wss
        const wsUrl = apiUrl.replace(/^http/, 'ws').replace(/\/api\/$/, '/ws/remote-terminal');

        const url = new URL(wsUrl);
        url.searchParams.append('token', token);
        url.searchParams.append('deviceId', 'cli-' + process.platform);
        url.searchParams.append('deviceName', 'Gitu CLI (' + process.platform + ')');

        this.ws = new WebSocket(url.toString());

        this.ws.on('open', () => {
            this.reconnectAttempts = 0;
            // console.log(chalk.gray('[Remote Terminal] Connected to Gitu cloud'));
        });

        this.ws.on('message', (data) => this.handleMessage(data));

        this.ws.on('close', () => {
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

            if (message.type === 'execute') {
                const { id, payload } = message;
                await this.executeCommand(id, payload);
            }
        } catch (err) {
            // console.error('[Remote Terminal] Error handling message:', err);
        }
    }

    private async executeCommand(id: string, payload: any) {
        const { command, args = [], cwd } = payload;

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
