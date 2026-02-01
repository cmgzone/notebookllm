import chalk from 'chalk';
import ora from 'ora';
import { ApiClient } from '../api.js';

export class HealthCommand {
  static async check(api: ApiClient, options: any) {
    const spinner = ora('Checking system health...').start();

    try {
      const health = await api.health();
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(health, null, 2));
        return;
      }

      console.log('');
      console.log(chalk.bold('System Health:'));
      console.log('');
      console.log(chalk.green('✓ Connected to NotebookLLM'));
      console.log(chalk.green('✓ Authentication: Valid'));
      console.log(chalk.green('✓ Backend: Healthy'));

      if (health.database) {
        console.log(chalk.green('✓ Database: Connected'));
      }

      if (health.redis) {
        console.log(chalk.green('✓ Redis: Connected'));
      }

      console.log('');
      console.log(chalk.cyan('Backend Version:'), health.version || 'Unknown');
      console.log(chalk.cyan('Uptime:'), health.uptime || 'Unknown');

    } catch (error: any) {
      spinner.fail('Health check failed');

      console.log('');
      console.log(chalk.red('✗ Cannot connect to backend'));

      if (error.response?.status === 401) {
        console.log(chalk.red('✗ Authentication failed'));
        console.log('');
        console.log('Check your API token:');
        console.log(chalk.cyan('  gitu config show'));
      } else {
        console.log('');
        console.log('Check your backend URL:');
        console.log(chalk.cyan('  gitu config show'));
      }

      throw error;
    }
  }

  static async whoami(api: ApiClient, options: any) {
    const spinner = ora('Fetching user info...').start();

    try {
      const data = await api.whoami();
      const user = data.user;
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(data, null, 2));
        return;
      }

      console.log('');
      console.log(chalk.bold('Current User:'));
      console.log('');
      console.log(chalk.cyan('ID:'), user.id);
      console.log(chalk.cyan('Email:'), user.email);
      console.log(chalk.cyan('Name:'), user.displayName || chalk.gray('(not set)'));
      console.log(chalk.cyan('Role:'), user.role);
      console.log(chalk.cyan('Created:'), new Date(user.createdAt).toLocaleString());

    } catch (error: any) {
      spinner.fail('Failed to fetch user info');
      throw error;
    }
  }
}
