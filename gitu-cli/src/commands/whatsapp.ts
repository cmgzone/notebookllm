import chalk from 'chalk';
import ora from 'ora';
import qrcodeTerminal from 'qrcode-terminal';
import { ApiClient } from '../api.js';

export class WhatsAppCommand {
  static async status(api: ApiClient, options: any) {
    const spinner = ora('Checking WhatsApp status...').start();
    try {
      const res = await api.whatsappStatus();
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(res, null, 2));
        return;
      }

      console.log(chalk.bold('\nWhatsApp Status'));
      console.log(chalk.gray(`Status: ${res.status}`));
      console.log(chalk.gray(`Device: ${res.device || '(none)'}`));
      console.log(chalk.gray(`Platform User ID: ${res.platformUserId || '(none)'}`));

      if (res.qrCode) {
        console.log(chalk.cyan('\nScan QR with WhatsApp (Linked Devices):\n'));
        qrcodeTerminal.generate(res.qrCode, { small: true });
        console.log('');
      }
    } catch (error: any) {
      spinner.fail('Failed to get WhatsApp status');
      console.error(chalk.red(error.message));
    }
  }

  static async connect(api: ApiClient, options: any) {
    const spinner = ora('Starting WhatsApp connection...').start();
    try {
      await api.whatsappConnect();
      spinner.succeed('WhatsApp connection started');

      const startedAt = Date.now();
      let printed = false;
      while (Date.now() - startedAt < 120_000) {
        const status = await api.whatsappStatus();
        if (status.status === 'connected') {
          console.log(chalk.green('\n✓ WhatsApp connected\n'));
          return;
        }
        if (status.qrCode && !printed) {
          printed = true;
          console.log(chalk.cyan('\nScan QR with WhatsApp (Linked Devices):\n'));
          qrcodeTerminal.generate(status.qrCode, { small: true });
          console.log('');
        }
        await new Promise(r => setTimeout(r, 2000));
      }

      console.log(chalk.yellow('\nTimed out waiting for WhatsApp QR/connect. Run:'));
      console.log(chalk.cyan('  gitu whatsapp status'));
      console.log('');
    } catch (error: any) {
      spinner.fail('Failed to start WhatsApp connection');
      console.error(chalk.red(error.message));
    }
  }

  static async disconnect(api: ApiClient, options: any) {
    const spinner = ora('Disconnecting WhatsApp...').start();
    try {
      const res = await api.whatsappDisconnect();
      spinner.stop();
      if (options.json) {
        console.log(JSON.stringify(res, null, 2));
        return;
      }
      console.log(chalk.green('✓ WhatsApp disconnected'));
    } catch (error: any) {
      spinner.fail('Failed to disconnect WhatsApp');
      console.error(chalk.red(error.message));
    }
  }

  static async linkCurrent(api: ApiClient, options: any) {
    const spinner = ora('Linking current WhatsApp session to your account...').start();
    try {
      const res = await api.whatsappLinkCurrent();
      spinner.stop();
      if (options.json) {
        console.log(JSON.stringify(res, null, 2));
        return;
      }
      console.log(chalk.green('✓ WhatsApp account linked'));
      console.log(chalk.gray(`Platform User ID: ${res.platformUserId}`));
      console.log(chalk.gray(`Display Name: ${res.displayName}`));
    } catch (error: any) {
      spinner.fail('Failed to link WhatsApp');
      console.error(chalk.red(error.message));
    }
  }
}

