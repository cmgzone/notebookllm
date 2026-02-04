import chalk from 'chalk';
import inquirer from 'inquirer';
import { v4 as uuidv4 } from 'uuid';
import { hostname, platform } from 'os';
import { ApiClient } from '../api.js';
import { ConfigManager } from '../config.js';
import { RemoteTerminalClient } from '../remote-terminal.js';
import qrcodeTerminal from 'qrcode-terminal';
import { printBrand } from '../ui/brand.js';

export class OnboardCommand {
  static async start(api: ApiClient, config: ConfigManager) {
    printBrand();
    console.log(chalk.bold.cyan('Gitu CLI Onboarding\n'));

    const existingToken = config.get('apiToken');
    const existingApiUrl = config.get('apiUrl');

    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'apiUrl',
        message: 'Backend API URL:',
        default: existingApiUrl || 'https://backend.taskiumnetwork.com/api/',
        filter: (val: string) => val.trim(),
      },
      {
        type: 'input',
        name: 'pairingToken',
        message: 'Pairing token (from app Settings → Terminal Connections):',
        default: '',
        filter: (val: string) => val.trim(),
      },
      {
        type: 'confirm',
        name: 'enableRemoteTerminal',
        message: 'Enable Remote Terminal on this PC (allows backend to request local commands)?',
        default: true,
      },
      {
        type: 'confirm',
        name: 'requireConfirm',
        message: 'Require local confirmation before running remote commands?',
        default: true,
        when: (a: any) => Boolean(a.enableRemoteTerminal),
      },
      {
        type: 'list',
        name: 'allowPreset',
        message: 'Remote allow rules preset:',
        choices: [
          { name: 'Default (no allowlist; confirmation required)', value: 'default' },
          { name: 'Safe dev (git, npm, node, python)', value: 'safe-dev' },
          { name: 'All commands (*)', value: 'all' },
        ],
        default: 'default',
        when: (a: any) => Boolean(a.enableRemoteTerminal),
      },
      {
        type: 'confirm',
        name: 'requestShellPermission',
        message: 'Request backend shell permission (needed to execute commands)?',
        default: true,
      },
      {
        type: 'confirm',
        name: 'allowUnsandboxed',
        message: 'Allow unsandboxed shell execution (required for Remote Terminal routing)?',
        default: false,
        when: (a: any) => Boolean(a.requestShellPermission),
      },
      {
        type: 'confirm',
        name: 'requestFilesPermission',
        message: 'Request file read/write permission for this repo path?',
        default: false,
      },
      {
        type: 'input',
        name: 'allowedPath',
        message: 'Allowed path (prefix) for file access:',
        default: process.cwd(),
        filter: (val: string) => val.trim(),
        when: (a: any) => Boolean(a.requestFilesPermission),
      },
      {
        type: 'confirm',
        name: 'autoApprove',
        message: 'Auto-approve these permission requests now (same user)?',
        default: true,
        when: (a: any) => Boolean(a.requestShellPermission || a.requestFilesPermission),
      },
      {
        type: 'confirm',
        name: 'setupWhatsApp',
        message: 'Connect and link WhatsApp now (backend-managed, QR scan)?',
        default: false,
      },
      {
        type: 'confirm',
        name: 'setupTelegram',
        message: 'Link Telegram now (requires Telegram user id from bot /id)?',
        default: false,
      },
      {
        type: 'input',
        name: 'telegramUserId',
        message: 'Telegram User ID (send /id to the bot to get it):',
        default: '',
        filter: (val: string) => val.trim(),
        when: (a: any) => Boolean(a.setupTelegram),
      },
    ]);

    let apiUrl = answers.apiUrl;
    if (!apiUrl.endsWith('/')) apiUrl += '/';
    config.set('apiUrl', apiUrl);

    if (!answers.pairingToken) {
      console.log(chalk.yellow('\nPairing token missing. You can link later with:'));
      console.log(chalk.cyan('  gitu auth GITU-XXXX-YYYY'));
      return;
    }

    let deviceId = config.get('deviceId');
    if (!deviceId) {
      deviceId = `cli-${process.platform}-${uuidv4().slice(0, 8)}`;
      config.set('deviceId', deviceId);
    }
    const deviceName = `${hostname()} (${platform()})`;

    const linkResult = await api.linkTerminal(answers.pairingToken, deviceId, deviceName);
    config.set('apiToken', linkResult.authToken);
    config.set('userId', linkResult.userId);
    (api as any).reinitialize();

    console.log(chalk.green('\n✓ CLI linked to your account'));

    // Auto-enable Remote Terminal after pairing
    const enableRemoteTerminal = answers.enableRemoteTerminal !== false;
    config.set('remoteTerminalEnabled', true);
    config.set('remoteTerminalRequireConfirm', enableRemoteTerminal ? Boolean(answers.requireConfirm) : true);
    if (enableRemoteTerminal) {
      if (answers.allowPreset === 'safe-dev') {
        config.set('remoteTerminalAllowedCommands', ['git ', 'npm ', 'node ', 'python ', 'python3 ']);
      } else if (answers.allowPreset === 'all') {
        config.set('remoteTerminalAllowedCommands', ['*']);
      } else {
        config.set('remoteTerminalAllowedCommands', []);
      }
    } else if (!Array.isArray(config.get('remoteTerminalAllowedCommands'))) {
      config.set('remoteTerminalAllowedCommands', []);
    }

    const rt = new RemoteTerminalClient(config);
    await rt.connect();
    console.log(chalk.green('✓ Remote Terminal configured'));

    const requestsToApprove: string[] = [];

    if (answers.requestShellPermission) {
      const allowedCommands = answers.enableRemoteTerminal
        ? (config.get('remoteTerminalAllowedCommands') || [])
        : ['git ', 'npm ', 'node '];

      const req = await api.requestPermission({
        resource: 'shell',
        actions: ['execute'],
        scope: {
          allowedCommands: Array.isArray(allowedCommands) ? allowedCommands : [],
          customScope: { allowUnsandboxed: Boolean(answers.allowUnsandboxed) },
        },
        reason: 'Allow CLI/WhatsApp tasks to run shell commands',
        expiresInDays: 30,
      });
      const id = req?.request?.id;
      if (id) requestsToApprove.push(id);
      console.log(chalk.green('✓ Shell permission requested'));
    }

    if (answers.requestFilesPermission) {
      const allowedPath = String(answers.allowedPath || '').trim();
      const req = await api.requestPermission({
        resource: 'files',
        actions: ['read', 'write'],
        scope: { allowedPaths: allowedPath ? [allowedPath] : [] },
        reason: 'Allow autonomous coding agent to read/write project files',
        expiresInDays: 30,
      });
      const id = req?.request?.id;
      if (id) requestsToApprove.push(id);
      console.log(chalk.green('✓ Files permission requested'));
    }

    if (answers.autoApprove && requestsToApprove.length > 0) {
      for (const id of requestsToApprove) {
        await api.approvePermissionRequest(id, { expiresInDays: 30 });
      }
      console.log(chalk.green('✓ Permission requests approved'));
    } else if (requestsToApprove.length > 0) {
      console.log(chalk.yellow('\nPermissions requested. Approve in app or via API.'));
    }

    console.log(chalk.cyan('\nNext steps:'));
    console.log(chalk.cyan('  gitu whoami'));
    console.log(chalk.cyan('  gitu chat'));
    console.log(chalk.cyan('  gitu code "Fix something in this repo"'));
    console.log(chalk.cyan('  gitu whatsapp status'));
    console.log(chalk.cyan('  gitu telegram status'));
    console.log('');

    if (answers.setupWhatsApp) {
      try {
        console.log(chalk.bold.cyan('\nWhatsApp Setup\n'));
        await api.whatsappConnect();

        const startedAt = Date.now();
        let printed = false;
        while (Date.now() - startedAt < 120_000) {
          const st = await api.whatsappStatus();
          if (st.status === 'connected') break;
          if (st.qrCode && !printed) {
            printed = true;
            console.log(chalk.cyan('Scan this QR in WhatsApp → Linked Devices:\n'));
            qrcodeTerminal.generate(st.qrCode, { small: true });
            console.log('');
          }
          await new Promise(r => setTimeout(r, 2000));
        }

        const finalStatus = await api.whatsappStatus();
        if (finalStatus.status === 'connected') {
          await api.whatsappLinkCurrent();
          console.log(chalk.green('✓ WhatsApp connected and linked'));
        } else {
          console.log(chalk.yellow('WhatsApp not connected yet. Use: gitu whatsapp status'));
        }
      } catch (e: any) {
        console.log(chalk.red(`WhatsApp setup failed: ${e.message}`));
      }
    }

    if (answers.setupTelegram) {
      const telegramUserId = String(answers.telegramUserId || '').trim();
      if (!telegramUserId) {
        console.log(chalk.yellow('Telegram user id not provided. Use: gitu telegram link <telegramUserId>'));
        return;
      }
      try {
        await api.telegramLink(telegramUserId, 'Telegram');
        console.log(chalk.green('✓ Telegram linked'));
      } catch (e: any) {
        console.log(chalk.red(`Telegram link failed: ${e.message}`));
      }
    }
  }
}
