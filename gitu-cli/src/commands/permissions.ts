import chalk from 'chalk';
import ora from 'ora';
import Table from 'cli-table3';
import { ApiClient } from '../api.js';

export class PermissionsCommand {
  static async list(api: ApiClient, options: any) {
    const spinner = ora('Fetching permissions...').start();
    try {
      const response = await api.listPermissions(options.resource);
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      const permissions = response.permissions || [];
      if (permissions.length === 0) {
        console.log(chalk.yellow('No permissions found.'));
        return;
      }

      const table = new Table({
        head: [chalk.bold('ID'), chalk.bold('Resource'), chalk.bold('Actions'), chalk.bold('Expires')],
        style: { head: ['cyan'] }
      });

      permissions.forEach((p: any) => {
        table.push([
          String(p.id).substring(0, 8) + '...',
          p.resource,
          Array.isArray(p.actions) ? p.actions.join(',') : String(p.actions || ''),
          p.expiresAt ? new Date(p.expiresAt).toLocaleDateString() : '(none)',
        ]);
      });

      console.log(table.toString());
    } catch (error: any) {
      spinner.fail('Failed to fetch permissions');
      console.error(chalk.red(error.message));
    }
  }

  static async requests(api: ApiClient, options: any) {
    const spinner = ora('Fetching permission requests...').start();
    try {
      const response = await api.listPermissionRequests(options.status);
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      const requests = response.requests || [];
      if (requests.length === 0) {
        console.log(chalk.yellow('No permission requests found.'));
        return;
      }

      const table = new Table({
        head: [chalk.bold('ID'), chalk.bold('Status'), chalk.bold('Resource'), chalk.bold('Actions')],
        style: { head: ['cyan'] }
      });

      requests.forEach((r: any) => {
        table.push([
          String(r.id).substring(0, 8) + '...',
          r.status,
          r.permission?.resource || '(unknown)',
          Array.isArray(r.permission?.actions) ? r.permission.actions.join(',') : '',
        ]);
      });

      console.log(table.toString());
      console.log(chalk.gray('\nApprove a request with:'));
      console.log(chalk.cyan('  gitu permissions approve <requestId>'));
    } catch (error: any) {
      spinner.fail('Failed to fetch permission requests');
      console.error(chalk.red(error.message));
    }
  }

  static async request(api: ApiClient, options: any) {
    const spinner = ora('Creating permission request...').start();
    try {
      const resource = options.resource;
      const actions = String(options.actions || '')
        .split(',')
        .map((s: string) => s.trim())
        .filter(Boolean);

      if (!resource) throw new Error('--resource is required');
      if (actions.length === 0) throw new Error('--actions is required (comma-separated)');
      if (!options.reason) throw new Error('--reason is required');

      let scope: any = undefined;
      if (options.allowedPaths) {
        scope = { ...(scope || {}), allowedPaths: String(options.allowedPaths).split(',').map((s: string) => s.trim()).filter(Boolean) };
      }
      if (options.allowedCommands) {
        scope = { ...(scope || {}), allowedCommands: String(options.allowedCommands).split(',').map((s: string) => s.trim()).filter(Boolean) };
      }
      if (options.allowUnsandboxed) {
        scope = { ...(scope || {}), customScope: { ...(scope?.customScope || {}), allowUnsandboxed: true } };
      }

      const response = await api.requestPermission({
        resource,
        actions,
        scope,
        reason: options.reason,
        expiresInDays: options.expiresInDays ? Number(options.expiresInDays) : undefined,
      });

      spinner.stop();
      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      console.log(chalk.green('✓ Permission request created'));
      console.log(chalk.gray(`Request ID: ${response.request?.id}`));
    } catch (error: any) {
      spinner.fail('Failed to create permission request');
      console.error(chalk.red(error.message));
    }
  }

  static async approve(api: ApiClient, requestId: string, options: any) {
    const spinner = ora('Approving request...').start();
    try {
      const response = await api.approvePermissionRequest(requestId, {
        expiresInDays: options.expiresInDays ? Number(options.expiresInDays) : undefined,
      });
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      console.log(chalk.green('✓ Request approved'));
      console.log(chalk.gray(`Permission ID: ${response.permission?.id}`));
    } catch (error: any) {
      spinner.fail('Failed to approve request');
      console.error(chalk.red(error.message));
    }
  }

  static async revoke(api: ApiClient, permissionId: string, options: any) {
    const spinner = ora('Revoking permission...').start();
    try {
      const response = await api.revokePermission(permissionId);
      spinner.stop();
      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }
      console.log(chalk.green('✓ Permission revoked'));
    } catch (error: any) {
      spinner.fail('Failed to revoke permission');
      console.error(chalk.red(error.message));
    }
  }
}

