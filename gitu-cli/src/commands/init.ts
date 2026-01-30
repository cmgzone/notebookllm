import chalk from 'chalk';
import inquirer from 'inquirer';
import { ApiClient } from '../api.js';
import Conf from 'conf';

const config = new Conf({ projectName: 'gitu-cli' });

export class InitCommand {
  static async start(api: ApiClient) {
    console.log(chalk.bold.cyan('\n🚀 Initialize Gitu CLI\n'));

    const answers = await inquirer.prompt([
      {
        type: 'input',
        name: 'token',
        message: 'Enter your Gitu Auth Token (from backend logs):',
        validate: (input: string) => input.length > 0 ? true : 'Token is required'
      },
      {
        type: 'input',
        name: 'apiUrl',
        message: 'Enter API URL:',
        default: 'http://localhost:3000'
      }
    ]);

    try {
      config.set('authToken', answers.token);
      config.set('apiUrl', answers.apiUrl);
      
      // Update API client
      api['baseUrl'] = answers.apiUrl;
      api['token'] = answers.token;

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
