import chalk from 'chalk';
import ora from 'ora';
import { ApiClient } from '../api.js';

export class DevicesCommand {
  static async list(api: ApiClient, options: any) {
    const spinner = ora('Fetching devices...').start();

    try {
      const devices = await api.listDevices();
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(devices, null, 2));
        return;
      }

      if (devices.length === 0) {
        console.log(chalk.yellow('No connected devices found'));
        return;
      }

      console.log('');
      console.log(chalk.bold(`Connected Devices (${devices.length}):`));
      console.log('');

      devices.forEach((device: any, index: number) => {
        console.log(chalk.cyan(`${index + 1}. ${device.name}`));
        console.log(`   ID: ${device.id}`);
        console.log(`   Type: ${device.type}`);
        console.log(`   Status: ${device.status}`);
        console.log(`   Last Seen: ${new Date(device.lastSeenAt).toLocaleString()}`);
        console.log('');
      });

    } catch (error: any) {
      spinner.fail('Failed to fetch devices');
      throw error;
    }
  }

  static async info(api: ApiClient, deviceId: string, options: any) {
    const spinner = ora('Fetching device details...').start();

    try {
      const device = await api.getDevice(deviceId);
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(device, null, 2));
        return;
      }

      console.log('');
      console.log(chalk.bold('Device Details:'));
      console.log('');
      console.log(chalk.cyan('ID:'), device.id);
      console.log(chalk.cyan('Name:'), device.name);
      console.log(chalk.cyan('Type:'), device.type);
      console.log(chalk.cyan('Status:'), device.status);
      console.log(chalk.cyan('Last Seen:'), new Date(device.lastSeenAt).toLocaleString());
      console.log(chalk.cyan('Created:'), new Date(device.createdAt).toLocaleString());

    } catch (error: any) {
      spinner.fail('Failed to fetch device details');
      throw error;
    }
  }

  static async remove(api: ApiClient, deviceId: string) {
    const spinner = ora('Removing device...').start();

    try {
      await api.removeDevice(deviceId);
      spinner.succeed(chalk.green('Device removed successfully'));
      
      console.log('');
      console.log('The device has been disconnected and removed from your account.');

    } catch (error: any) {
      spinner.fail('Failed to remove device');
      throw error;
    }
  }
}
