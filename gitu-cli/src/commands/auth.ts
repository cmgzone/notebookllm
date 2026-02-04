import chalk from 'chalk';
import ora from 'ora';
import { v4 as uuidv4 } from 'uuid';
import { ApiClient } from '../api.js';
import { ConfigManager } from '../config.js';
import { hostname, platform } from 'os';
import { RemoteTerminalClient } from '../remote-terminal.js';
import { printBrand } from '../ui/brand.js';

export class AuthCommand {
    static async link(api: ApiClient, config: ConfigManager, token?: string) {
        if (!token) {
            console.error(chalk.red('Error: Pairing token is required.'));
            console.log(chalk.yellow('\nGet a pairing token from the NotebookLLM app:'));
            console.log('Settings -> Gitu Assistant -> Terminal Connections -> Generate Token');
            console.log(chalk.cyan('\nThen run: ') + chalk.bold('gitu auth GITU-XXXX-YYYY'));
            process.exit(1);
        }

        printBrand();
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
            config.set('remoteTerminalEnabled', true);
            if (!config.has('remoteTerminalRequireConfirm')) {
                config.set('remoteTerminalRequireConfirm', true);
            }

            // Re-initialize API client with the new token
            (api as any).reinitialize();

            spinner.succeed(chalk.green('Terminal linked successfully!'));
            console.log(chalk.gray(`\nDevice: ${deviceName}`));
            console.log(chalk.gray(`Expires: ${new Date(result.expiresAt).toLocaleString()}`));
            console.log(chalk.gray('Remote Terminal: enabled (local computer access)'));

            const existingAllow = config.get('remoteTerminalAllowedCommands');
            const allowList = Array.isArray(existingAllow) && existingAllow.length > 0
                ? existingAllow
                : ['git ', 'npm ', 'node ', 'python ', 'python3 ', 'rg ', 'find ', 'ls ', 'dir '];
            if (!Array.isArray(existingAllow) || existingAllow.length === 0) {
                config.set('remoteTerminalAllowedCommands', allowList);
            }

            try {
                const req = await api.requestPermission({
                    resource: 'shell',
                    actions: ['execute'],
                    scope: {
                        allowedCommands: allowList,
                        customScope: { allowUnsandboxed: true },
                    },
                    reason: 'Enable local CLI remote terminal control',
                    expiresInDays: 30,
                });
                const id = req?.request?.id;
                if (id) {
                    await api.approvePermissionRequest(id, { expiresInDays: 30 });
                    console.log(chalk.green('✓ Shell permission approved for local execution'));
                }
            } catch (e: any) {
                console.log(chalk.yellow('Shell permission request failed. Approve it manually in the app if needed.'));
            }

            try {
                const rt = new RemoteTerminalClient(config);
                await rt.connect();
                console.log(chalk.green('✓ Remote Terminal connected'));
            } catch {
                console.log(chalk.yellow('Remote Terminal could not connect right now. It will auto-connect in gitu chat/run.'));
            }

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
