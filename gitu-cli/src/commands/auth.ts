import chalk from 'chalk';
import ora from 'ora';
import { v4 as uuidv4 } from 'uuid';
import { ApiClient } from '../api.js';
import { ConfigManager } from '../config.js';
import { hostname, platform } from 'os';

export class AuthCommand {
    static async link(api: ApiClient, config: ConfigManager, token?: string) {
        if (!token) {
            console.error(chalk.red('Error: Pairing token is required.'));
            console.log(chalk.yellow('\nGet a pairing token from the NotebookLLM app:'));
            console.log('Settings -> Gitu Assistant -> Terminal Connections -> Generate Token');
            console.log(chalk.cyan('\nThen run: ') + chalk.bold('gitu auth GITU-XXXX-YYYY'));
            process.exit(1);
        }

        const spinner = ora('Linking terminal...').start();
        try {
            // Get or generate device ID
            let deviceId = config.get('deviceId');
            if (!deviceId) {
                deviceId = uuidv4();
                config.set('deviceId', deviceId);
            }

            const deviceName = `${hostname()} (${platform()})`;

            const result = await api.linkTerminal(token, deviceId, deviceName);

            config.set('apiToken', result.authToken);
            config.set('userId', result.userId);

            // Re-initialize API client with the new token
            (api as any).reinitialize();

            spinner.succeed(chalk.green('Terminal linked successfully!'));
            console.log(chalk.gray(`\nDevice: ${deviceName}`));
            console.log(chalk.gray(`Expires: ${new Date(result.expiresAt).toLocaleString()}`));

            console.log(chalk.cyan('\nTest your connection:'));
            console.log(chalk.bold('  gitu whoami'));

        } catch (error: any) {
            spinner.fail(chalk.red('Linking failed!'));
            console.error(chalk.red(`Error: ${error.response?.data?.error || error.message}`));

            if (error.response?.status === 401) {
                console.log(chalk.yellow('\nTip: Pairing tokens expire after 5 minutes. Try generating a new one in the app.'));
            }
        }
    }
}
