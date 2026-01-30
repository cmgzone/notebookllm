import chalk from 'chalk';
import ora from 'ora';
import { ApiClient } from '../api.js';

export class RunCommand {
  static async execute(api: ApiClient, command: string, options: any) {
    const spinner = ora(`Running: ${command}`).start();
    try {
      const response = await api.executeShell(command);
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      if (response.exitCode === 0) {
        console.log(chalk.green('✅ Success'));
      } else {
        console.log(chalk.red(`❌ Failed (Exit Code: ${response.exitCode})`));
      }

      if (response.stdout) {
        console.log(chalk.bold('STDOUT:'));
        console.log(response.stdout);
      }

      if (response.stderr) {
        console.log(chalk.bold.red('STDERR:'));
        console.error(response.stderr);
      }

    } catch (error: any) {
      spinner.fail('Command execution failed');
      console.error(chalk.red(error.message));
    }
  }
}
