#!/usr/bin/env node

import { Command } from 'commander';
import chalk from 'chalk';
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

const program = new Command();
const config = new ConfigManager();
const api = new ApiClient(config);

program
  .name('gitu')
  .description('Gitu Universal Assistant CLI')
  .version('1.0.0');

program
  .command('init')
  .description('Initialize Gitu CLI configuration')
  .action(() => InitCommand.start(api, config));

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
  .action(() => ChatCommand.start(api));

// Run command
program
  .command('run <command>')
  .description('Execute a single natural language instruction')
  .option('--json', 'Output as JSON')
  .action((command, options) => RunCommand.execute(api, command, options));

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

try {
  await program.parseAsync(process.argv);
} catch (error: any) {
  if (error.code === 'commander.help') {
    process.exit(0);
  }

  console.error(chalk.red('Error:'), error.message);

  if (error.response?.status === 401) {
    console.error(chalk.yellow('\nAuthentication failed. Please check your API token:'));
    console.error(chalk.cyan('  gitu config set-token YOUR_TOKEN'));
  } else if (error.code === 'ECONNREFUSED') {
    console.error(chalk.yellow('\nCannot connect to backend. Please check your API URL:'));
    console.error(chalk.cyan('  gitu config set-url https://your-backend.com'));
  }

  process.exit(1);
}
