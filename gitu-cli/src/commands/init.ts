import chalk from 'chalk';
import inquirer from 'inquirer';
import { ApiClient } from '../api.js';
import { ConfigManager } from '../config.js';
import { AuthCommand } from './auth.js';

export class InitCommand {
  static async start(api: ApiClient, config: ConfigManager) {
    console.log(chalk.bold.cyan('\n🚀 Initialize Gitu CLI\n'));

    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'token',
        message: 'Enter your API Token (starts with nllm_) or pairing token (GITU-...) or leave blank:',
        filter: (val: string) => val.trim(),
        validate: (input: string) => true // Allow empty if they want to use 'auth' later
      },
      {
        type: 'input',
        name: 'apiUrl',
        message: 'Enter API URL:',
        default: config.get('apiUrl') || 'https://backend.taskiumnetwork.com/api/'
      },
      {
        type: 'confirm',
        name: 'remoteTerminalEnabled',
        message: 'Enable Remote Terminal (allows backend to run commands on this computer)?',
        default: false
      },
      {
        type: 'confirm',
        name: 'remoteTerminalRequireConfirm',
        message: 'Require local confirmation before running remote commands?',
        default: true,
        when: (a: any) => Boolean(a.remoteTerminalEnabled),
      }
    ]);

    try {
      let apiUrl = answers.apiUrl;
      if (!apiUrl.endsWith('/')) apiUrl += '/';
      config.set('apiUrl', apiUrl);
      config.set('remoteTerminalEnabled', Boolean(answers.remoteTerminalEnabled));
      if (answers.remoteTerminalEnabled) {
        config.set('remoteTerminalRequireConfirm', Boolean(answers.remoteTerminalRequireConfirm));
      }

      if (answers.token) {
        if (String(answers.token).toUpperCase().startsWith('GITU-')) {
          (api as any).reinitialize();
          await AuthCommand.link(api, config, answers.token);
          return;
        }

        config.set('apiToken', answers.token);
        // Re-initialize API client with new config
        (api as any).reinitialize();

        console.log(chalk.green('\n✅ Configuration saved!'));

        // Test connection
        process.stdout.write(chalk.gray('Testing connection... '));
        const me = await api.whoami();
        console.log(chalk.green('Success!'));
        console.log(chalk.gray(`Connected as: ${me.user.email} (${me.user.role})`));
      } else {
        console.log(chalk.green('\n✅ API URL saved!'));
        console.log(chalk.yellow('\nNo token provided. To link your terminal, run:'));
        console.log(chalk.bold('  gitu auth <pairing-token>'));
        console.log(chalk.gray('(Get a pairing token in the app under Settings -> Terminal)'));
      }

    } catch (error: any) {
      console.log(chalk.red('Failed!'));
      console.error(chalk.red(`Error: ${error.message}`));
      if (error?.response?.status === 401) {
        console.log(chalk.yellow('Authentication failed.'));
        console.log(chalk.gray('If you used a pairing token, run:'));
        console.log(chalk.cyan('  gitu auth GITU-XXXX-YYYY'));
        console.log(chalk.gray('If you used an API token, ensure it starts with nllm_.'));
        return;
      }
      console.log(chalk.yellow('Please check your settings and try again.'));
    }
  }
}
