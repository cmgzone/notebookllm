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
    console.log(chalk.cyan('Default Format:'), allConfig.defaultFormat || 'terminal');
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
}
