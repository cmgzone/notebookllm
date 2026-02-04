#!/usr/bin/env node

import { Command } from 'commander';
import chalk from 'chalk';
import { createRequire } from 'module';
import { ConfigManager } from './config.js';
import { ApiClient } from './api.js';
import { QRCommand } from './commands/qr.js';
import { SessionsCommand } from './commands/sessions.js';
import { DevicesCommand } from './commands/devices.js';
import { ConfigCommand } from './commands/config.js';
import { HealthCommand } from './commands/health.js';
import { AgentCommand } from './commands/agent.js';
import { ChatCommand } from './commands/chat.js';
import { RunCommand } from './commands/run.js';
import { NotebookCommand } from './commands/notebook.js';
import { InitCommand } from './commands/init.js';
import { AliasCommand } from './commands/alias.js';
import { AuthCommand } from './commands/auth.js';
import { CommandsCommand } from './commands/commands.js';
import { MissionCommand } from './commands/mission.js';
import { CodeCommand } from './commands/code.js';
import { OnboardCommand } from './commands/onboard.js';
import { PermissionsCommand } from './commands/permissions.js';
import { WhatsAppCommand } from './commands/whatsapp.js';
import { TelegramCommand } from './commands/telegram.js';
import { StatusCommand } from './commands/status.js';
import { RemoteTerminalCommand } from './commands/remoteTerminal.js';
import { renderBrand } from './ui/brand.js';

const program = new Command();
const config = new ConfigManager();
const api = new ApiClient(config);
const require = createRequire(import.meta.url);
const pkg = require('../package.json') as { version?: string };

program.hook('preAction', async (_thisCommand, actionCommand) => {
  const cmdName = actionCommand?.name?.();
  const parentName = actionCommand?.parent?.name?.();

  if (parentName === 'remote-terminal' || cmdName === 'remote-terminal') return;
  if (parentName === 'config' && cmdName === 'remote-terminal') return;

  try {
    RemoteTerminalCommand.ensureDaemonRunning(config, { silent: true });
  } catch {}
});

program
  .name('gitu')
  .description('Gitu Universal Assistant CLI')
  .version(pkg.version ?? '0.0.0');

program.addHelpText('beforeAll', renderBrand());

program
  .command('init')
  .description('Initialize Gitu CLI configuration')
  .action(() => InitCommand.start(api, config));

program
  .command('onboard')
  .description('Interactive onboarding: link device, remote terminal, permissions')
  .action(() => OnboardCommand.start(api, config));

const permsCmd = program
  .command('permissions')
  .description('Manage backend permissions (shell/files/etc)');

permsCmd
  .command('list')
  .description('List current permissions')
  .option('--resource <resource>', 'Filter by resource, e.g. shell/files')
  .option('--json', 'Output as JSON')
  .action((options) => PermissionsCommand.list(api, options));

permsCmd
  .command('requests')
  .description('List permission requests')
  .option('--status <status>', 'pending|approved|denied')
  .option('--json', 'Output as JSON')
  .action((options) => PermissionsCommand.requests(api, options));

permsCmd
  .command('request')
  .description('Request a permission')
  .requiredOption('--resource <resource>', 'Resource name, e.g. shell/files')
  .requiredOption('--actions <actions>', 'Comma-separated actions, e.g. execute,read,write')
  .requiredOption('--reason <reason>', 'Reason for request')
  .option('--allowed-paths <paths>', 'Comma-separated allowed paths (files)')
  .option('--allowed-commands <cmds>', 'Comma-separated allowed command prefixes (shell)')
  .option('--allow-unsandboxed', 'Allow unsandboxed shell execution')
  .option('--expires-in-days <days>', 'Expiry in days', '30')
  .option('--json', 'Output as JSON')
  .action((options) => PermissionsCommand.request(api, options));

permsCmd
  .command('approve <requestId>')
  .description('Approve a permission request')
  .option('--expires-in-days <days>', 'Expiry in days', '30')
  .option('--json', 'Output as JSON')
  .action((requestId, options) => PermissionsCommand.approve(api, requestId, options));

permsCmd
  .command('revoke <permissionId>')
  .description('Revoke a permission')
  .option('--json', 'Output as JSON')
  .action((permissionId, options) => PermissionsCommand.revoke(api, permissionId, options));

const whatsappCmd = program
  .command('whatsapp')
  .description('Connect and link WhatsApp (backend-managed)');

whatsappCmd
  .command('status')
  .description('Show WhatsApp adapter status and QR if available')
  .option('--json', 'Output as JSON')
  .action((options) => WhatsAppCommand.status(api, options));

whatsappCmd
  .command('connect')
  .description('Start WhatsApp connection and print QR')
  .option('--json', 'Output as JSON')
  .action((options) => WhatsAppCommand.connect(api, options));

whatsappCmd
  .command('disconnect')
  .description('Disconnect WhatsApp adapter')
  .option('--json', 'Output as JSON')
  .action((options) => WhatsAppCommand.disconnect(api, options));

whatsappCmd
  .command('link-current')
  .description('Link the currently connected WhatsApp account to this user')
  .option('--json', 'Output as JSON')
  .action((options) => WhatsAppCommand.linkCurrent(api, options));

const telegramCmd = program
  .command('telegram')
  .description('Link Telegram user id to your account');

telegramCmd
  .command('status')
  .description('Show Telegram adapter status and link state')
  .option('--json', 'Output as JSON')
  .action((options) => TelegramCommand.status(api, options));

telegramCmd
  .command('link <telegramUserId>')
  .description('Link your Telegram user id (get it by sending /id to the bot)')
  .option('--name <displayName>', 'Display name', 'Telegram')
  .option('--json', 'Output as JSON')
  .action((telegramUserId, options) => TelegramCommand.link(api, telegramUserId, options));

program
  .command('commands')
  .description('Show quick reference for commands and chat slash-commands')
  .action(() => CommandsCommand.show());

program
  .command('code <objective...>')
  .description('Start an autonomous coding mission (swarm)')
  .option('--json', 'Output as JSON')
  .action((objectiveParts, options) => CodeCommand.start(api, config, objectiveParts.join(' '), options));

const missionCmd = program
  .command('mission')
  .description('Manage autonomous swarm missions');

missionCmd
  .command('start <objective...>')
  .description('Start a new mission')
  .option('--json', 'Output as JSON')
  .action((objectiveParts, options) => MissionCommand.start(api, objectiveParts.join(' '), options));

missionCmd
  .command('active')
  .description('List active missions')
  .option('--json', 'Output as JSON')
  .action((options) => MissionCommand.active(api, options));

missionCmd
  .command('show <missionId>')
  .description('Show mission status')
  .option('--detail', 'Include detail payload (plan/task status)')
  .option('--json', 'Output as JSON')
  .action((missionId, options) => MissionCommand.show(api, missionId, options));

missionCmd
  .command('watch <missionId>')
  .description('Watch mission status until completion')
  .option('--json', 'Output as JSON')
  .action((missionId, options) => MissionCommand.watch(api, missionId, options));

missionCmd
  .command('stop <missionId>')
  .description('Stop a mission')
  .option('--json', 'Output as JSON')
  .action((missionId, options) => MissionCommand.stop(api, missionId, options));

missionCmd
  .command('synthesize <missionId>')
  .description('Synthesize final report for a mission')
  .option('--json', 'Output as JSON')
  .action((missionId, options) => MissionCommand.synthesize(api, missionId, options));

program
  .command('auth [token]')
  .description('Authenticate CLI with a pairing token from the app')
  .action((token) => AuthCommand.link(api, config, token));

program
  .command('alias [shell]')
  .description('Generate shell alias script (bash/zsh/powershell)')
  .action((shell) => AliasCommand.show(shell));

// Config commands
const configCmd = program
  .command('config')
  .description('Manage CLI configuration');

configCmd
  .command('set-token <token>')
  .description('Set API authentication token')
  .action((token) => ConfigCommand.setToken(config, token));

configCmd
  .command('set-url <url>')
  .description('Set backend API URL')
  .action((url) => ConfigCommand.setUrl(config, url));

configCmd
  .command('show')
  .description('Show current configuration')
  .action(() => ConfigCommand.show(config));

configCmd
  .command('reset')
  .description('Reset configuration to defaults')
  .action(() => ConfigCommand.reset(config));

configCmd
  .command('remote-terminal <mode>')
  .description('Enable/disable remote execution on this computer (on/off)')
  .action((mode) => {
    const normalized = String(mode).trim().toLowerCase();
    if (normalized === 'on' || normalized === 'enable' || normalized === 'enabled') {
      ConfigCommand.setRemoteTerminal(config, true);
      return;
    }
    if (normalized === 'off' || normalized === 'disable' || normalized === 'disabled') {
      ConfigCommand.setRemoteTerminal(config, false);
      return;
    }
    console.error(chalk.red('Invalid mode. Use: on|off'));
    process.exit(1);
  });

configCmd
  .command('remote-confirm <mode>')
  .description('Require local confirmation for remote commands (on/off)')
  .action((mode) => {
    const normalized = String(mode).trim().toLowerCase();
    if (normalized === 'on' || normalized === 'enable' || normalized === 'enabled') {
      ConfigCommand.setRemoteTerminalConfirm(config, true);
      return;
    }
    if (normalized === 'off' || normalized === 'disable' || normalized === 'disabled') {
      ConfigCommand.setRemoteTerminalConfirm(config, false);
      return;
    }
    console.error(chalk.red('Invalid mode. Use: on|off'));
    process.exit(1);
  });

configCmd
  .command('remote-allow <rule>')
  .description('Add an allow rule for remote execution (prefix match, or "*")')
  .action((rule) => ConfigCommand.addRemoteTerminalAllowRule(config, rule));

configCmd
  .command('remote-allow-clear')
  .description('Clear remote execution allow rules')
  .action(() => ConfigCommand.clearRemoteTerminalAllowRules(config));

// QR commands
const qrCmd = program
  .command('qr')
  .description('Generate QR codes for pairing');

qrCmd
  .command('generate')
  .description('Generate QR code for terminal pairing')
  .option('-f, --format <format>', 'Output format: terminal, png, svg', 'terminal')
  .option('-o, --output <file>', 'Output file path (for png/svg)')
  .action((options) => QRCommand.generate(api, options));

// Sessions commands
const sessionsCmd = program
  .command('sessions')
  .description('Manage Gitu sessions');

sessionsCmd
  .command('list')
  .description('List your active sessions')
  .option('--json', 'Output as JSON')
  .action((options) => SessionsCommand.list(api, options));

sessionsCmd
  .command('info <sessionId>')
  .description('Get session details')
  .option('--json', 'Output as JSON')
  .action((sessionId, options) => SessionsCommand.info(api, sessionId, options));

sessionsCmd
  .command('revoke <sessionId>')
  .description('Revoke a session')
  .action((sessionId) => SessionsCommand.revoke(api, sessionId));

// Devices commands
const devicesCmd = program
  .command('devices')
  .description('Manage connected devices');

devicesCmd
  .command('list')
  .description('List your connected devices')
  .option('--json', 'Output as JSON')
  .action((options) => DevicesCommand.list(api, options));

devicesCmd
  .command('info <deviceId>')
  .description('Get device details')
  .option('--json', 'Output as JSON')
  .action((deviceId, options) => DevicesCommand.info(api, deviceId, options));

devicesCmd
  .command('remove <deviceId>')
  .description('Remove a device')
  .action((deviceId) => DevicesCommand.remove(api, deviceId));

// Health command
program
  .command('health')
  .description('Check system health and connection')
  .option('--json', 'Output as JSON')
  .action((options) => HealthCommand.check(api, options));

program
  .command('status')
  .description('Show CLI and remote terminal status')
  .option('--json', 'Output as JSON')
  .action((options) => StatusCommand.show(api, config, options));

const remoteTerminalCmd = program
  .command('remote-terminal')
  .description('Manage local remote terminal connection');

remoteTerminalCmd
  .command('start')
  .description('Run remote terminal in foreground')
  .action(() => RemoteTerminalCommand.start(config));

remoteTerminalCmd
  .command('daemon')
  .description('Run remote terminal in background')
  .action(() => RemoteTerminalCommand.daemon(config));

remoteTerminalCmd
  .command('stop')
  .description('Stop background remote terminal')
  .action(() => RemoteTerminalCommand.stop(config));

remoteTerminalCmd
  .command('autostart <mode>')
  .description('Enable or disable autostart on login (on/off)')
  .action((mode) => RemoteTerminalCommand.autostart(config, mode));

// Agent commands
const agentCmd = program
  .command('agent')
  .description('Manage autonomous agents');

agentCmd
  .command('list')
  .description('List active agents')
  .option('--json', 'Output as JSON')
  .action((options) => AgentCommand.list(api, options));

agentCmd
  .command('spawn <task>')
  .description('Spawn a new agent')
  .option('--json', 'Output as JSON')
  .action((task, options) => AgentCommand.spawn(api, task, options));

agentCmd
  .command('watch <agentId>')
  .description('Watch agent progress')
  .option('--json', 'Output as JSON')
  .action((agentId, options) => AgentCommand.watch(api, agentId, options));

// Chat command
program
  .command('chat')
  .description('Start interactive chat session')
  .action(() => ChatCommand.start(api, config));

// Run command
program
  .command('run <command>')
  .description('Execute a single natural language instruction')
  .option('--json', 'Output as JSON')
  .action((command, options) => RunCommand.execute(api, config, command, options));

// Notebook commands
const notebookCmd = program
  .command('notebook')
  .description('Manage notebooks');

notebookCmd
  .command('list')
  .description('List your notebooks')
  .option('--json', 'Output as JSON')
  .action((options) => NotebookCommand.list(api, options));

notebookCmd
  .command('query <notebookId> <question>')
  .description('Ask a question to a notebook')
  .option('--json', 'Output as JSON')
  .action((notebookId, question, options) => NotebookCommand.query(api, notebookId, question, options));

// Whoami command
program
  .command('whoami')
  .description('Show current user information')
  .option('--json', 'Output as JSON')
  .action((options) => HealthCommand.whoami(api, options));

// Error handling
program.exitOverride();

const handleCliError = (error: any) => {
  const commanderExitCodes = new Set(['commander.help', 'commander.helpDisplayed', 'commander.version']);
  if (commanderExitCodes.has(error?.code)) {
    process.exitCode = 0;
    return;
  }

  console.error(chalk.red('Error:'), error?.message || String(error));

  if (error?.response?.status === 401) {
    console.error(chalk.yellow('\nAuthentication failed. Please check your API token:'));
    console.error(chalk.cyan('  gitu config set-token YOUR_TOKEN'));
  } else if (error?.code === 'ECONNREFUSED') {
    console.error(chalk.yellow('\nCannot connect to backend. Please check your API URL:'));
    console.error(chalk.cyan('  gitu config set-url https://your-backend.com'));
  }

  process.exit(1);
};

program.parseAsync(process.argv).catch(handleCliError);
