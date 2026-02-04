import chalk from 'chalk';
import { spawn } from 'child_process';
import { ConfigManager } from '../config.js';
import { RemoteTerminalClient } from '../remote-terminal.js';
import fs from 'fs';
import path from 'path';
import { homedir } from 'os';

function buildStartupScriptContent(): string {
  const nodePath = process.execPath;
  const scriptPath = process.argv[1];
  if (scriptPath) {
    return `"${nodePath}" "${scriptPath}" remote-terminal daemon`;
  }
  return `gitu remote-terminal daemon`;
}

function getWindowsStartupPath(): string | null {
  const appData = process.env.APPDATA;
  if (!appData) return null;
  return path.join(appData, 'Microsoft', 'Windows', 'Start Menu', 'Programs', 'Startup', 'gitu-remote-terminal.bat');
}

function getMacLaunchAgentPath(): string {
  return path.join(homedir(), 'Library', 'LaunchAgents', 'com.gitu.remote-terminal.plist');
}

function getLinuxSystemdServicePath(): string {
  return path.join(homedir(), '.config', 'systemd', 'user', 'gitu-remote-terminal.service');
}

function getLinuxSystemdWantsPath(): string {
  return path.join(homedir(), '.config', 'systemd', 'user', 'default.target.wants', 'gitu-remote-terminal.service');
}

function buildMacLaunchAgentContent(): string {
  const nodePath = process.execPath;
  const scriptPath = process.argv[1];
  const programArgs = scriptPath
    ? `<array><string>${nodePath}</string><string>${scriptPath}</string><string>remote-terminal</string><string>start</string></array>`
    : `<array><string>gitu</string><string>remote-terminal</string><string>start</string></array>`;

  return `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>com.gitu.remote-terminal</string>
  <key>ProgramArguments</key>
  ${programArgs}
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <true/>
</dict>
</plist>
`;
}

function buildLinuxSystemdServiceContent(): string {
  const nodePath = process.execPath;
  const scriptPath = process.argv[1];
  const execStart = scriptPath
    ? `"${nodePath}" "${scriptPath}" remote-terminal start`
    : `gitu remote-terminal start`;

  return `[Unit]
Description=Gitu Remote Terminal
After=network.target

[Service]
Type=simple
ExecStart=${execStart}
Restart=on-failure
RestartSec=3

[Install]
WantedBy=default.target
`;
}

export class RemoteTerminalCommand {
  static ensureDaemonRunning(config: ConfigManager, options?: { silent?: boolean }) {
    const silent = options?.silent === true;
    const enabled = Boolean(config.get('remoteTerminalEnabled'));
    const token = config.get('apiToken');

    if (!enabled || !token) return;

    const existingPid = config.get('remoteTerminalDaemonPid');
    if (typeof existingPid === 'number' && existingPid > 0) {
      try {
        process.kill(existingPid, 0);
        return;
      } catch {
        config.set('remoteTerminalDaemonPid', undefined as any);
      }
    }

    const nodePath = process.execPath;
    const scriptPath = process.argv[1];
    const args = scriptPath
      ? [scriptPath, 'remote-terminal', 'start']
      : ['remote-terminal', 'start'];

    const child = spawn(nodePath, args, {
      detached: true,
      stdio: 'ignore',
      windowsHide: true,
    });

    child.unref();
    if (child.pid) {
      config.set('remoteTerminalDaemonPid', child.pid);
    }

    if (!silent) {
      console.log(chalk.green('Remote Terminal daemon started'));
    }
  }

  static async start(config: ConfigManager) {
    if (!config.get('remoteTerminalEnabled')) {
      config.set('remoteTerminalEnabled', true);
    }

    const rt = new RemoteTerminalClient(config);
    await rt.connect();

    console.log(chalk.green('Remote Terminal connected. Press Ctrl+C to stop.'));

    const shutdown = () => {
      rt.disconnect();
      process.exit(0);
    };

    process.on('SIGINT', shutdown);
    process.on('SIGTERM', shutdown);

    // Keep process alive
    await new Promise(() => {});
  }

  static async daemon(config: ConfigManager) {
    this.ensureDaemonRunning(config, { silent: false });
  }

  static async stop(config: ConfigManager) {
    const pid = config.get('remoteTerminalDaemonPid');
    if (!pid) {
      console.log(chalk.yellow('No Remote Terminal daemon pid found.'));
      return;
    }

    try {
      process.kill(pid);
      console.log(chalk.green('Remote Terminal daemon stopped'));
    } catch (e) {
      console.log(chalk.yellow('Could not stop daemon. You may need to end it manually.'));
    } finally {
      config.set('remoteTerminalDaemonPid', undefined as any);
    }
  }

  static async autostart(config: ConfigManager, mode: string) {
    const normalized = String(mode || '').trim().toLowerCase();
    const isOn = normalized === 'on' || normalized === 'enable' || normalized === 'enabled';
    const isOff = normalized === 'off' || normalized === 'disable' || normalized === 'disabled';

    if (!isOn && !isOff) {
      console.log(chalk.red('Invalid mode. Use: on|off'));
      process.exit(1);
    }

    if (process.platform === 'win32') {
      const startupPath = getWindowsStartupPath();
      if (!startupPath) {
        console.log(chalk.red('Unable to resolve Windows Startup folder.'));
        process.exit(1);
      }

      if (isOn) {
        const content = buildStartupScriptContent();
        fs.mkdirSync(path.dirname(startupPath), { recursive: true });
        fs.writeFileSync(startupPath, `@echo off\r\n${content}\r\n`, 'utf-8');
        config.set('remoteTerminalStartupPath', startupPath);
        console.log(chalk.green('Remote Terminal autostart enabled'));
        console.log(chalk.gray(`Startup script: ${startupPath}`));
        return;
      }

      try {
        fs.rmSync(startupPath, { force: true });
      } catch {}
      config.set('remoteTerminalStartupPath', undefined as any);
      console.log(chalk.green('Remote Terminal autostart disabled'));
      return;
    }

    if (process.platform === 'darwin') {
      const launchPath = getMacLaunchAgentPath();
      if (isOn) {
        const content = buildMacLaunchAgentContent();
        fs.mkdirSync(path.dirname(launchPath), { recursive: true });
        fs.writeFileSync(launchPath, content, 'utf-8');
        config.set('remoteTerminalStartupPath', launchPath);
        console.log(chalk.green('Remote Terminal autostart enabled'));
        console.log(chalk.gray(`LaunchAgent: ${launchPath}`));
        console.log(chalk.gray('Activate now: launchctl load -w ~/Library/LaunchAgents/com.gitu.remote-terminal.plist'));
        return;
      }

      try {
        fs.rmSync(launchPath, { force: true });
      } catch {}
      config.set('remoteTerminalStartupPath', undefined as any);
      console.log(chalk.green('Remote Terminal autostart disabled'));
      console.log(chalk.gray('Deactivate now: launchctl unload -w ~/Library/LaunchAgents/com.gitu.remote-terminal.plist'));
      return;
    }

    if (process.platform === 'linux') {
      const servicePath = getLinuxSystemdServicePath();
      const wantsPath = getLinuxSystemdWantsPath();
      if (isOn) {
        const content = buildLinuxSystemdServiceContent();
        fs.mkdirSync(path.dirname(servicePath), { recursive: true });
        fs.writeFileSync(servicePath, content, 'utf-8');
        fs.mkdirSync(path.dirname(wantsPath), { recursive: true });
        try {
          if (!fs.existsSync(wantsPath)) {
            fs.symlinkSync(servicePath, wantsPath);
          }
        } catch {}
        config.set('remoteTerminalStartupPath', servicePath);
        console.log(chalk.green('Remote Terminal autostart enabled'));
        console.log(chalk.gray(`Systemd user unit: ${servicePath}`));
        console.log(chalk.gray('Activate now: systemctl --user daemon-reload && systemctl --user enable --now gitu-remote-terminal'));
        return;
      }

      try {
        fs.rmSync(wantsPath, { force: true });
      } catch {}
      try {
        fs.rmSync(servicePath, { force: true });
      } catch {}
      config.set('remoteTerminalStartupPath', undefined as any);
      console.log(chalk.green('Remote Terminal autostart disabled'));
      console.log(chalk.gray('Deactivate now: systemctl --user disable --now gitu-remote-terminal'));
      return;
    }

    console.log(chalk.yellow('Autostart is not supported on this platform.'));
    console.log(chalk.yellow('You can run: gitu remote-terminal daemon'));
  }
}
