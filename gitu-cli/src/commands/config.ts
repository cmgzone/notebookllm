import chalk from 'chalk';
import { ConfigManager } from '../config.js';

export class ConfigCommand {
  static setToken(config: ConfigManager, token: string) {
    config.set('apiToken', token);
    console.log(chalk.green('✓ API token saved'));
    console.log('');
    console.log('Test your connection:');
    console.log(chalk.cyan('  gitu health'));
  }

  static setUrl(config: ConfigManager, url: string) {
    // Validate URL
    try {
      new URL(url);
    } catch (error) {
      console.error(chalk.red('Error: Invalid URL format'));
      process.exit(1);
    }

    config.set('apiUrl', url);
    console.log(chalk.green('✓ API URL saved'));
    console.log('');
    console.log('Test your connection:');
    console.log(chalk.cyan('  gitu health'));
  }

  static show(config: ConfigManager) {
    const allConfig = config.getAll();

    console.log('');
    console.log(chalk.bold('Current Configuration:'));
    console.log('');
    console.log(chalk.cyan('API URL:'), allConfig.apiUrl || chalk.gray('(not set)'));
    console.log(chalk.cyan('API Token:'), allConfig.apiToken ? chalk.green('✓ Set') : chalk.red('✗ Not set'));
    console.log(chalk.cyan('User ID:'), allConfig.userId || chalk.gray('(not set)'));
    console.log(chalk.cyan('Device ID:'), allConfig.deviceId || chalk.gray('(not set)'));
    console.log(chalk.cyan('Default Format:'), allConfig.defaultFormat || 'terminal');
    console.log(chalk.cyan('Remote Terminal:'), allConfig.remoteTerminalEnabled ? chalk.green('enabled') : chalk.gray('disabled'));
    console.log(chalk.cyan('Remote Confirm:'), allConfig.remoteTerminalRequireConfirm ? chalk.green('on') : chalk.gray('off'));
    console.log(chalk.cyan('Remote Allowlist:'), Array.isArray(allConfig.remoteTerminalAllowedCommands) ? `${allConfig.remoteTerminalAllowedCommands.length} rule(s)` : '0 rule(s)');
    console.log('');

    if (!allConfig.apiToken) {
      console.log(chalk.yellow('⚠ API token not set. Get one from:'));
      console.log('  Settings → API Tokens in the NotebookLLM app');
      console.log('');
      console.log('Then run:');
      console.log(chalk.cyan('  gitu config set-token YOUR_TOKEN'));
    }
  }

  static reset(config: ConfigManager) {
    config.reset();
    console.log(chalk.green('✓ Configuration reset to defaults'));
    console.log('');
    console.log('Set your API token:');
    console.log(chalk.cyan('  gitu config set-token YOUR_TOKEN'));
  }

  static setRemoteTerminal(config: ConfigManager, enabled: boolean) {
    config.set('remoteTerminalEnabled', enabled);
    console.log(chalk.green(`✓ Remote Terminal ${enabled ? 'enabled' : 'disabled'}`));
    console.log(chalk.gray('This controls whether the backend may execute commands on this computer via the remote-terminal channel.'));
  }

  static setRemoteTerminalConfirm(config: ConfigManager, enabled: boolean) {
    config.set('remoteTerminalRequireConfirm', enabled);
    console.log(chalk.green(`✓ Remote confirmation ${enabled ? 'enabled' : 'disabled'}`));
  }

  static addRemoteTerminalAllowRule(config: ConfigManager, rule: string) {
    const existing = config.get('remoteTerminalAllowedCommands');
    const list = Array.isArray(existing) ? existing.slice() : [];
    list.push(rule);
    config.set('remoteTerminalAllowedCommands', list);
    console.log(chalk.green(`✓ Added allow rule: ${rule}`));
  }

  static clearRemoteTerminalAllowRules(config: ConfigManager) {
    config.set('remoteTerminalAllowedCommands', []);
    console.log(chalk.green('✓ Cleared remote allow rules'));
  }
}
