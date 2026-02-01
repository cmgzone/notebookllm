import chalk from 'chalk';
import inquirer from 'inquirer';
import { ApiClient } from '../api.js';
import { ConfigManager } from '../config.js';

export class InitCommand {
  static async start(api: ApiClient, config: ConfigManager) {
    console.log(chalk.bold.cyan('\n🚀 Initialize Gitu CLI\n'));

    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'token',
        message: 'Enter your API Token (starts with nllm_) or skip to use "gitu auth":',
        filter: (val: string) => val.trim(),
        validate: (input: string) => true // Allow empty if they want to use 'auth' later
      },
      {
        type: 'input',
        name: 'apiUrl',
        message: 'Enter API URL:',
        default: config.get('apiUrl') || 'https://backend.taskiumnetwork.com/api/'
      }
    ]);

    try {
      let apiUrl = answers.apiUrl;
      if (!apiUrl.endsWith('/')) apiUrl += '/';
      config.set('apiUrl', apiUrl);

      if (answers.token) {
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
      console.log(chalk.yellow('Please check your token and try again.'));
    }
  }
}
