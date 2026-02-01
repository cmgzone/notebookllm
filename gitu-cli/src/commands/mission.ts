import chalk from 'chalk';
import ora from 'ora';
import Table from 'cli-table3';
import { ApiClient } from '../api.js';

export class MissionCommand {
  static async start(api: ApiClient, objective: string, options: any) {
    const spinner = ora('Starting mission...').start();
    try {
      const response = await api.startMission(objective);
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      const mission = response.mission;
      console.log(chalk.green('\n✓ Mission started'));
      console.log(chalk.gray(`Mission ID: ${mission.id}`));
      console.log(chalk.gray(`Status: ${mission.status}`));
      console.log(chalk.gray(`Objective: ${mission.objective}`));
      console.log(chalk.gray('\nTip: watch updates with:'));
      console.log(chalk.cyan(`  gitu mission watch ${mission.id}`));
      console.log('');
    } catch (error: any) {
      spinner.fail('Failed to start mission');
      console.error(chalk.red(error.message));
    }
  }

  static async active(api: ApiClient, options: any) {
    const spinner = ora('Fetching active missions...').start();
    try {
      const response = await api.listActiveMissions();
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      const missions = response.missions || [];
      if (missions.length === 0) {
        console.log(chalk.yellow('No active missions.'));
        return;
      }

      const table = new Table({
        head: [chalk.bold('ID'), chalk.bold('Status'), chalk.bold('Agents'), chalk.bold('Objective')],
        style: { head: ['cyan'] }
      });

      missions.forEach((m: any) => {
        const statusColor = m.status === 'completed' ? chalk.green :
          m.status === 'failed' ? chalk.red :
            m.status === 'active' ? chalk.blue : chalk.yellow;

        table.push([
          String(m.id).substring(0, 8) + '...',
          statusColor(m.status),
          String(m.agentCount ?? m.agent_count ?? 0),
          String(m.objective).length > 60 ? String(m.objective).substring(0, 57) + '...' : String(m.objective),
        ]);
      });

      console.log(table.toString());
    } catch (error: any) {
      spinner.fail('Failed to fetch missions');
      console.error(chalk.red(error.message));
    }
  }

  static async show(api: ApiClient, missionId: string, options: any) {
    const spinner = ora('Fetching mission...').start();
    try {
      const response = options.detail ? await api.getMissionDetail(missionId) : await api.getMission(missionId);
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      const mission = response.mission;
      console.log(chalk.bold('\nMission'));
      console.log(chalk.gray(`ID: ${mission.id}`));
      console.log(chalk.gray(`Status: ${mission.status}`));
      console.log(chalk.gray(`Agents: ${mission.agentCount ?? mission.agent_count ?? 0}`));
      console.log(chalk.gray(`Objective: ${mission.objective}`));
      console.log('');

      if (options.detail && response.detail) {
        console.log(chalk.bold('Plan'));
        const plan = response.detail.plan || response.detail.context?.plan;
        if (plan) console.log(JSON.stringify(plan, null, 2));
        console.log('');
      }
    } catch (error: any) {
      spinner.fail('Failed to fetch mission');
      console.error(chalk.red(error.message));
    }
  }

  static async stop(api: ApiClient, missionId: string, options: any) {
    const spinner = ora('Stopping mission...').start();
    try {
      const response = await api.stopMission(missionId);
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      console.log(chalk.green('✓ Mission stopped'));
    } catch (error: any) {
      spinner.fail('Failed to stop mission');
      console.error(chalk.red(error.message));
    }
  }

  static async watch(api: ApiClient, missionId: string, options: any) {
    console.log(chalk.cyan(`Watching mission ${missionId}...\n`));

    let lastStatus: string | null = null;
    while (true) {
      try {
        const response = await api.getMission(missionId);
        const mission = response.mission;

        if (options.json) {
          console.log(JSON.stringify(mission, null, 2));
          return;
        }

        if (mission.status !== lastStatus) {
          console.log(chalk.gray(`Status: ${mission.status}`));
          lastStatus = mission.status;
        }

        if (['completed', 'failed'].includes(mission.status)) {
          console.log(chalk.bold(`\nMission ${mission.status.toUpperCase()}`));
          return;
        }

        await new Promise(resolve => setTimeout(resolve, 2000));
      } catch (error: any) {
        console.error(chalk.red('Error polling mission:'), error.message);
        return;
      }
    }
  }
}

