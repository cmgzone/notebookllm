import { describe, it, expect, jest } from '@jest/globals';
import { EventEmitter } from 'events';
import path from 'path';
import { GituShellManager } from '../services/gituShellManager.js';

function createMockChildProcess(exitCode: number) {
  const child = new EventEmitter() as any;
  child.stdout = new EventEmitter();
  child.stderr = new EventEmitter();
  child.kill = jest.fn();
  setImmediate(() => child.emit('close', exitCode));
  return child;
}

describe('GituShellManager', () => {
  it('runs sandboxed commands via docker with resource limits', async () => {
    const spawnMock = jest.fn(() => createMockChildProcess(0));
    const poolMock = { query: jest.fn(async () => ({ rows: [{ id: 'audit-1' }] })) } as any;
    const permissionManagerMock = {
      listPermissions: jest.fn(async () => [
        {
          actions: ['execute'],
          scope: { allowedCommands: ['echo'], allowedPaths: ['*'] },
        },
      ]),
    } as any;

    const mgr = new GituShellManager({
      spawn: spawnMock,
      pool: poolMock,
      permissionManager: permissionManagerMock,
    });

    const result = await mgr.execute('user-1', { command: 'echo', args: ['hello'], cwd: 'C:\\tmp', sandboxed: true });

    expect(result.success).toBe(true);
    expect(result.mode).toBe('sandboxed');
    expect(spawnMock).toHaveBeenCalledTimes(1);
    const calls = spawnMock.mock.calls as unknown as any[];
    const [spawnCommand, dockerArgs] = calls[0] as [string, string[]];
    expect(spawnCommand).toBe('docker');
    expect(dockerArgs).toContain('--network');
    expect(dockerArgs).toContain('none');
    expect(dockerArgs).toContain('--cpus');
    expect(dockerArgs).toContain('0.5');
    expect(dockerArgs).toContain('--memory');
    expect(dockerArgs).toContain('512m');
    expect(dockerArgs).toContain('--pids-limit');
    expect(dockerArgs).toContain('64');

    const vIndex = dockerArgs.indexOf('-v');
    expect(vIndex).toBeGreaterThan(-1);
    expect(dockerArgs[vIndex + 1]).toBe(`${path.resolve('C:\\tmp')}:/workspace`);
  });

  it('blocks unsandboxed execution unless explicitly allowed', async () => {
    const spawnMock = jest.fn(() => createMockChildProcess(0));
    const poolMock = { query: jest.fn(async () => ({ rows: [{ id: 'audit-1' }] })) } as any;
    const permissionManagerMock = {
      listPermissions: jest.fn(async () => [
        {
          actions: ['execute'],
          scope: { allowedCommands: ['*'], allowedPaths: ['*'] },
        },
      ]),
    } as any;

    const mgr = new GituShellManager({
      spawn: spawnMock,
      pool: poolMock,
      permissionManager: permissionManagerMock,
    });

    const result = await mgr.execute('user-1', { command: process.execPath, args: ['-v'], sandboxed: false });

    expect(result.success).toBe(false);
    expect(result.error).toBe('UNSANDBOXED_MODE_NOT_ALLOWED');
    expect(spawnMock).not.toHaveBeenCalled();
  });

  it('blocks commands not included in allowedCommands', async () => {
    const spawnMock = jest.fn(() => createMockChildProcess(0));
    const poolMock = { query: jest.fn(async () => ({ rows: [{ id: 'audit-1' }] })) } as any;
    const permissionManagerMock = {
      listPermissions: jest.fn(async () => [
        {
          actions: ['execute'],
          scope: { allowedCommands: ['echo'], allowedPaths: ['*'] },
        },
      ]),
    } as any;

    const mgr = new GituShellManager({
      spawn: spawnMock,
      pool: poolMock,
      permissionManager: permissionManagerMock,
    });

    const result = await mgr.execute('user-1', { command: 'rm', args: ['-rf', '/'], cwd: 'C:\\tmp', sandboxed: true });

    expect(result.success).toBe(false);
    expect(result.error).toBe('SHELL_COMMAND_NOT_ALLOWED');
    expect(spawnMock).not.toHaveBeenCalled();
  });
});
