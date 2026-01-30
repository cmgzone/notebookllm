import chalk from 'chalk';
import ora from 'ora';
import Table from 'cli-table3';
import { ApiClient } from '../api.js';

export class NotebookCommand {
  static async list(api: ApiClient, options: any) {
    const spinner = ora('Fetching notebooks...').start();
    try {
      const response = await api.listNotebooks();
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      if (response.notebooks.length === 0) {
        console.log(chalk.yellow('No notebooks found.'));
        return;
      }

      const table = new Table({
        head: [chalk.bold('Title'), chalk.bold('ID'), chalk.bold('Sources'), chalk.bold('Updated')],
        style: { head: ['cyan'] }
      });

      response.notebooks.forEach((nb: any) => {
        table.push([
          nb.title.length > 40 ? nb.title.substring(0, 37) + '...' : nb.title,
          nb.id.substring(0, 8) + '...',
          nb.sourceCount.toString(),
          new Date(nb.updatedAt).toLocaleDateString()
        ]);
      });

      console.log(table.toString());

    } catch (error: any) {
      spinner.fail('Failed to list notebooks');
      console.error(chalk.red(error.message));
    }
  }

  static async query(api: ApiClient, notebookId: string, query: string, options: any) {
    const spinner = ora('Querying notebook...').start();
    try {
      const response = await api.queryNotebook(notebookId, query);
      spinner.stop();

      if (options.json) {
        console.log(JSON.stringify(response, null, 2));
        return;
      }

      console.log(chalk.bold.cyan('\nAnswer:'));
      console.log(response.answer);
      
      if (response.sources && response.sources.length > 0) {
        console.log(chalk.bold.yellow('\nSources:'));
        response.sources.forEach((src: any) => {
          console.log(`- ${src.title} (Relevance: ${Math.round(src.score * 100)}%)`);
        });
      }
      console.log();

    } catch (error: any) {
      spinner.fail('Query failed');
      console.error(chalk.red(error.message));
    }
  }
}
