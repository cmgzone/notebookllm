import chalk from 'chalk';
import ora from 'ora';
import QRCode from 'qrcode';
import qrcodeTerminal from 'qrcode-terminal';
import { writeFileSync } from 'fs';
import { ApiClient } from '../api.js';

export class QRCommand {
  static async generate(api: ApiClient, options: any) {
    const spinner = ora('Generating QR code...').start();

    try {
      const result = await api.generateQR();
      spinner.succeed('QR code generated!');

      console.log('');
      console.log(chalk.cyan('Pairing Token:'), result.token);
      console.log(chalk.cyan('Expires:'), new Date(result.expiresAt).toLocaleString());
      console.log('');

      if (options.format === 'terminal') {
        // Display QR in terminal
        qrcodeTerminal.generate(result.qrData, { small: true });
        console.log('');
        console.log(chalk.green('✓ Scan this QR code with the NotebookLLM mobile app'));
      } else if (options.format === 'png') {
        // Save as PNG
        const outputPath = options.output || 'gitu-qr.png';
        await QRCode.toFile(outputPath, result.qrData);
        console.log(chalk.green(`✓ QR code saved to: ${outputPath}`));
      } else if (options.format === 'svg') {
        // Save as SVG
        const outputPath = options.output || 'gitu-qr.svg';
        const svg = await QRCode.toString(result.qrData, { type: 'svg' });
        writeFileSync(outputPath, svg);
        console.log(chalk.green(`✓ QR code saved to: ${outputPath}`));
      }

      console.log('');
      console.log(chalk.yellow('Next steps:'));
      console.log('  1. Open NotebookLLM mobile app');
      console.log('  2. Go to Settings → Gitu → Pair Terminal');
      console.log('  3. Scan the QR code');
      console.log('  4. Verify with: gitu sessions list');

    } catch (error: any) {
      spinner.fail('Failed to generate QR code');
      throw error;
    }
  }
}
