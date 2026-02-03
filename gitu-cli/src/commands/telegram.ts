import chalk from 'chalk';
import ora from 'ora';
import { ApiClient } from '../api.js';

export class TelegramCommand {
  static async status(api: ApiClient, options: any) {
    const spinner = ora('Checking Telegram status...').start();
    try {
      const res = await api.telegramStatus();
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(res, null, 2));
        return;
      }

      console.log(chalk.bold('\nTelegram Status'));
      console.log(chalk.gray(`Adapter: ${res.status}`));
      console.log(chalk.gray(`Bot: ${res.bot || '(unknown)'}`));
      console.log(chalk.gray(`Linked User ID: ${res.platformUserId || '(not linked)'}`));
      console.log(chalk.gray(`Display Name: ${res.displayName || '(n/a)'}`));
      console.log(chalk.gray('\nTo link: send /id to your bot in Telegram, then:'));
      console.log(chalk.cyan('  gitu telegram link <telegramUserId>'));
      console.log('');
    } catch (error: any) {
      spinner.fail('Failed to get Telegram status');
      console.error(chalk.red(error.message));
    }
  }

  static async link(api: ApiClient, telegramUserId: string, options: any) {
    const spinner = ora('Linking Telegram account...').start();
    try {
      const res = await api.telegramLink(telegramUserId, options.name);
      spinner.stop();
      if (options.json) {
        console.log(JSON.stringify(res, null, 2));
        return;
      }
      console.log(chalk.green('✓ Telegram account linked'));
      console.log(chalk.gray(`Telegram User ID: ${res.platformUserId}`));
      console.log(chalk.gray(`Display Name: ${res.displayName}`));
    } catch (error: any) {
      spinner.fail('Failed to link Telegram');
      console.error(chalk.red(error.message));
    }
  }
}

