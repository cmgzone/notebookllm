import chalk from 'chalk';
import ora from 'ora';
import Table from 'cli-table3';
import { ApiClient } from '../api.js';

export class AgentCommand {
  static async list(api: ApiClient, options: any) {
    const spinner = ora('Fetching agents...').start();
    try {
      const response = await api.listAgents();
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      if (response.agents.length === 0) {
        console.log(chalk.yellow('No agents found.'));
        return;
      }

      const table = new Table({
        head: [chalk.bold('ID'), chalk.bold('Status'), chalk.bold('Task'), chalk.bold('Date')],
        style: { head: ['cyan'] }
      });

      response.agents.forEach((agent: any) => {
        const statusColor = agent.status === 'completed' ? chalk.green : 
                           agent.status === 'failed' ? chalk.red : 
                           agent.status === 'active' ? chalk.blue : chalk.yellow;
        
        table.push([
          agent.id.substring(0, 8) + '...',
          statusColor(agent.status),
          agent.task.length > 50 ? agent.task.substring(0, 47) + '...' : agent.task,
          new Date(agent.created_at).toLocaleDateString()
        ]);
      });

      console.log(table.toString());

    } catch (error: any) {
      spinner.fail('Failed to list agents');
      console.error(chalk.red(error.message));
    }
  }

  static async spawn(api: ApiClient, task: string, options: any) {
    const spinner = ora('Spawning agent...').start();
    try {
      const response = await api.spawnAgent(task);
      spinner.succeed('Agent spawned successfully!');

      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      const agent = response.agent;
      console.log(chalk.green(`\nAgent ID: ${agent.id}`));
      console.log(`Task: ${agent.task}`);
      console.log(chalk.gray('\nUse "gitu agent watch <id>" to monitor progress.'));

    } catch (error: any) {
      spinner.fail('Failed to spawn agent');
      console.error(chalk.red(error.message));
    }
  }

  static async watch(api: ApiClient, agentId: string, options: any) {
    console.log(chalk.cyan(`Watching agent ${agentId}...\n`));
    
    let lastHistoryLength = 0;
    let isComplete = false;

    while (!isComplete) {
      try {
        const response = await api.getAgent(agentId);
        const agent = response.agent;

        if (options.json) {
            // In JSON mode, just dump current state and exit
            console.log(JSON.stringify(agent, null, 2));
            return;
        }

        // Check for new memory entries
        const history = agent.memory?.history || [];
        if (history.length > lastHistoryLength) {
          const newEntries = history.slice(lastHistoryLength);
          newEntries.forEach((entry: any) => {
            const role = entry.role === 'user' ? chalk.blue('USER') : chalk.green('AGENT');
            console.log(`${role}: ${entry.content}\n`);
          });
          lastHistoryLength = history.length;
        }

        if (agent.status === 'completed') {
          console.log(chalk.bold.green('✅ Task Completed!'));
          if (agent.result) {
             console.log(chalk.gray('Result:'), agent.result.output);
          }
          isComplete = true;
        } else if (agent.status === 'failed') {
          console.log(chalk.bold.red('❌ Task Failed'));
          if (agent.result) {
             console.log(chalk.gray('Error:'), agent.result.error);
          }
          isComplete = true;
        } else {
          // Wait before polling again
          await new Promise(resolve => setTimeout(resolve, 2000));
        }

      } catch (error: any) {
        console.error(chalk.red('Error polling agent:'), error.message);
        break;
      }
    }
  }
}
