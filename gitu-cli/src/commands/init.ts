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
        message: 'Enter your Gitu Auth Token:',
        validate: (input: string) => input.length > 0 ? true : 'Token is required'
      },
      {
        type: 'input',
        name: 'apiUrl',
        message: 'Enter API URL:',
        default: 'https://notebookllm-ufj7.onrender.com/api'
      }
    ]);

    try {
      config.set('apiToken', answers.token);
      config.set('apiUrl', answers.apiUrl);

      // Re-initialize API client with new config
      (api as any).reinitialize();

      console.log(chalk.green('\n✅ Configuration saved!'));

      // Test connection
      process.stdout.write(chalk.gray('Testing connection... '));
      const me = await api.whoami();
      console.log(chalk.green('Success!'));
      console.log(chalk.gray(`Connected as: ${me.user.email} (${me.user.role})`));

    } catch (error: any) {
      console.log(chalk.red('Failed!'));
      console.error(chalk.red(`Error: ${error.message}`));
      console.log(chalk.yellow('Please check your token and try again.'));
    }
  }
}
