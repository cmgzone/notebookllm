import { describe, it, expect } from '@jest/globals';
import { createServer } from 'http';
import WebSocket from 'ws';
import jwt from 'jsonwebtoken';
import { GituShellWebSocketService } from '../services/gituShellWebSocketService.js';

describe('GituShellWebSocketService', () => {
  it('streams stdout/stderr over websocket and completes', async () => {
    process.env.JWT_SECRET = 'test-secret';
    const token = jwt.sign({ userId: 'user-1' }, process.env.JWT_SECRET, { expiresIn: '5m' });

    const shellManager = {
      execute: async (_userId: string, _req: any, hooks: any) => {
        hooks?.registerCancel?.(() => {});
        hooks?.onStdoutChunk?.(Buffer.from('out-1\n'));
        hooks?.onStderrChunk?.(Buffer.from('err-1\n'));
        return {
          success: true,
          mode: 'sandboxed' as const,
          command: 'echo',
          args: ['x'],
          cwd: 'C:\\tmp',
          exitCode: 0,
          stdout: 'out-1\n',
          stderr: 'err-1\n',
          timedOut: false,
          durationMs: 1,
          stdoutTruncated: false,
          stderrTruncated: false,
          auditLogId: 'audit-1',
        };
      },
    };

    const service = new GituShellWebSocketService({ shellManager });
    const server = createServer();
    service.initialize(server);

    await new Promise<void>((resolve) => server.listen(0, resolve));
    const address = server.address();
    if (!address || typeof address === 'string') throw new Error('No server address');
    const url = `ws://127.0.0.1:${address.port}/ws/shell?token=${encodeURIComponent(token)}`;

    const ws = new WebSocket(url);
    const events: any[] = [];

    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('timeout')), 5000);
      ws.on('error', reject);
      ws.on('message', (data) => {
        events.push(JSON.parse(data.toString()));
        if (events.some(e => e.type === 'connected')) {
          clearTimeout(timeout);
          resolve();
        }
      });
    });

    ws.send(JSON.stringify({ type: 'execute', payload: { command: 'echo', args: ['x'], cwd: 'C:\\tmp', sandboxed: true } }));

    await new Promise<void>((resolve, reject) => {
      const timeout = setTimeout(() => reject(new Error('timeout')), 5000);
      ws.on('message', (data) => {
        events.push(JSON.parse(data.toString()));
        if (events.some(e => e.type === 'shell_completed')) {
          clearTimeout(timeout);
          resolve();
        }
      });
      ws.on('error', reject);
    });

    const started = events.find(e => e.type === 'shell_started');
    expect(started).toBeTruthy();
    const executionId = started.payload.executionId;

    expect(events.some(e => e.type === 'shell_output' && e.payload.executionId === executionId && e.payload.stream === 'stdout')).toBe(true);
    expect(events.some(e => e.type === 'shell_output' && e.payload.executionId === executionId && e.payload.stream === 'stderr')).toBe(true);

    const completed = events.find(e => e.type === 'shell_completed' && e.payload.executionId === executionId);
    expect(completed.payload.result.success).toBe(true);

    await new Promise<void>((resolve) => {
      ws.once('close', () => resolve());
      ws.close();
    });
    service.shutdown();
    await new Promise<void>((resolve) => server.close(() => resolve()));
  });
});
