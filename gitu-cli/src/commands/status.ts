import chalk from 'chalk';
import { ApiClient } from '../api.js';
import { ConfigManager } from '../config.js';
import { printBrand } from '../ui/brand.js';

export class StatusCommand {
  static async show(api: ApiClient, config: ConfigManager, options: any) {
    if (!options?.json) {
      printBrand();
    }
    const [me, remote] = await Promise.all([
      api.whoami().catch(() => null),
      api.getRemoteTerminalStatus().catch(() => null),
    ]);

    if (options?.json) {
      console.log(JSON.stringify({ me, remote, config: config.getAll() }, null, 2));
      return;
    }

    const all = config.getAll();
    const userEmail = me?.user?.email || '(unknown)';
    const userRole = me?.user?.role || '(unknown)';

    console.log(chalk.bold('\nGitu Status'));
    console.log(chalk.gray(`API URL: ${all.apiUrl || '(not set)'}`));
    console.log(chalk.gray(`User: ${userEmail} (${userRole})`));
    console.log(chalk.gray(`Device ID: ${all.deviceId || '(not set)'}`));
    console.log(chalk.gray(`Remote Terminal: ${all.remoteTerminalEnabled ? 'enabled' : 'disabled'}`));

    if (remote && remote.success) {
      console.log(chalk.gray(`Remote Terminal Connected: ${remote.connected ? 'yes' : 'no'}`));
      const devices = Array.isArray(remote.devices) ? remote.devices : [];
      if (devices.length > 0) {
        console.log(chalk.gray('Remote Devices:'));
        for (const d of devices) {
          const caps = Array.isArray(d.capabilities) && d.capabilities.length > 0 ? ` [${d.capabilities.join(', ')}]` : '';
          console.log(chalk.gray(`- ${d.deviceName} (${d.deviceId})${caps}`));
        }
      }
    } else {
      console.log(chalk.yellow('Remote Terminal Connected: unknown (backend not reachable)'));
    }

    console.log('');
  }
}
