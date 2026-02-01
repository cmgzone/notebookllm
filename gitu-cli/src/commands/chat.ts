import chalk from 'chalk';
import readline from 'readline';
import { ApiClient } from '../api.js';
import { RemoteTerminalClient } from '../remote-terminal.js';
import { ConfigManager } from '../config.js';
import { v4 as uuidv4 } from 'uuid';

export class ChatCommand {
  static async start(api: ApiClient, config: ConfigManager) {
    const sessionId = uuidv4();
    const remoteTerminal = new RemoteTerminalClient(config);
    await remoteTerminal.connect();

    console.log(chalk.bold.cyan('\n🤖 Gitu Interactive Chat'));
    console.log(chalk.gray('Type your message and press Enter.'));
    console.log(chalk.gray('Type "exit" or "quit" to leave.\n'));

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      prompt: chalk.cyan('You> ')
    });

    rl.prompt();

    rl.on('line', async (line) => {
      const input = line.trim();

      if (['exit', 'quit'].includes(input.toLowerCase())) {
        rl.close();
        return;
      }

      if (!input) {
        rl.prompt();
        return;
      }

      try {
        process.stdout.write(chalk.gray('Thinking...'));
        const response = await api.sendMessage(input, [], sessionId);

        // Clear "Thinking..."
        readline.clearLine(process.stdout, 0);
        readline.cursorTo(process.stdout, 0);

        console.log(`${chalk.green('Gitu>')} ${response.content}\n`);
      } catch (error: any) {
        readline.clearLine(process.stdout, 0);
        readline.cursorTo(process.stdout, 0);
        console.error(chalk.red(`Error: ${error.message}\n`));
      }

      rl.prompt();
    });

    rl.on('close', () => {
      remoteTerminal.disconnect();
      console.log(chalk.cyan('\nGoodbye!'));
      process.exit(0);
    });
  }
}
