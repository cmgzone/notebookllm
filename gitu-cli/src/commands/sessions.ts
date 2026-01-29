import chalk from 'chalk';
import ora from 'ora';
import { ApiClient } from '../api.js';

export class SessionsCommand {
  static async list(api: ApiClient, options: any) {
    const spinner = ora('Fetching sessions...').start();

    try {
      const sessions = await api.listSessions();
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(sessions, null, 2));
        return;
      }

      if (sessions.length === 0) {
        console.log(chalk.yellow('No active sessions found'));
        console.log('');
        console.log('Generate a QR code to pair a new terminal:');
        console.log(chalk.cyan('  gitu qr generate'));
        return;
      }

      console.log('');
      console.log(chalk.bold(`Active Sessions (${sessions.length}):`));
      console.log('');

      sessions.forEach((session: any, index: number) => {
        console.log(chalk.cyan(`${index + 1}. ${session.id}`));
        console.log(`   Platform: ${session.platform}`);
        console.log(`   Status: ${session.status}`);
        console.log(`   Created: ${new Date(session.createdAt).toLocaleString()}`);
        console.log(`   Last Active: ${new Date(session.lastActiveAt).toLocaleString()}`);
        console.log('');
      });

    } catch (error: any) {
      spinner.fail('Failed to fetch sessions');
      throw error;
    }
  }

  static async info(api: ApiClient, sessionId: string, options: any) {
    const spinner = ora('Fetching session details...').start();

    try {
      const session = await api.getSession(sessionId);
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(session, null, 2));
        return;
      }

      console.log('');
      console.log(chalk.bold('Session Details:'));
      console.log('');
      console.log(chalk.cyan('ID:'), session.id);
      console.log(chalk.cyan('Platform:'), session.platform);
      console.log(chalk.cyan('Status:'), session.status);
      console.log(chalk.cyan('Created:'), new Date(session.createdAt).toLocaleString());
      console.log(chalk.cyan('Last Active:'), new Date(session.lastActiveAt).toLocaleString());
      
      if (session.deviceInfo) {
        console.log('');
        console.log(chalk.bold('Device Info:'));
        console.log(chalk.cyan('  Name:'), session.deviceInfo.name);
        console.log(chalk.cyan('  Type:'), session.deviceInfo.type);
      }

    } catch (error: any) {
      spinner.fail('Failed to fetch session details');
      throw error;
    }
  }

  static async revoke(api: ApiClient, sessionId: string) {
    const spinner = ora('Revoking session...').start();

    try {
      await api.revokeSession(sessionId);
      spinner.succeed(chalk.green('Session revoked successfully'));
      
      console.log('');
      console.log('The session has been terminated and the device disconnected.');

    } catch (error: any) {
      spinner.fail('Failed to revoke session');
      throw error;
    }
  }
}
