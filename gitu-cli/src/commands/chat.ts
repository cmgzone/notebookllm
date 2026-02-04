import chalk from 'chalk';
import readline from 'readline';
import { ApiClient } from '../api.js';
import { RemoteTerminalClient } from '../remote-terminal.js';
import { ConfigManager } from '../config.js';
import { v4 as uuidv4 } from 'uuid';
import { printBrand } from '../ui/brand.js';

export class ChatCommand {
  static async start(api: ApiClient, config: ConfigManager) {
    const sessionId = uuidv4();
    const remoteTerminal = new RemoteTerminalClient(config);
    await remoteTerminal.connect();

    printBrand();
    console.log(chalk.bold.cyan('Gitu Interactive Chat'));
    if (!config.get('remoteTerminalEnabled')) {
      console.log(chalk.gray('Remote Terminal: disabled (commands will run on server if executed)'));
    } else {
      console.log(chalk.gray('Remote Terminal: enabled'));
    }
    console.log(chalk.gray('Type your message and press Enter.'));
    console.log(chalk.gray('Type /help to see commands.'));
    console.log(chalk.gray('Type "exit" or "quit" to leave.\n'));

    const rl = readline.createInterface({
      input: process.stdin,
      output: process.stdout,
      prompt: chalk.cyan('You> ')
    });

    const showHelp = () => {
      console.log(chalk.bold('\nChat Commands'));
      console.log(chalk.gray('  /help                          Show this help'));
      console.log(chalk.gray('  /whoami                        Show current user'));
      console.log(chalk.gray('  /shell <command>               Run a shell command (backend or remote terminal)'));
      console.log(chalk.gray('  /code <objective>              Start an autonomous coding mission'));
      console.log(chalk.gray('  /notebooks                     List notebooks'));
      console.log(chalk.gray('  /notebook <id> <question>      Query a notebook'));
      console.log(chalk.gray('  /agent list                    List agents'));
      console.log(chalk.gray('  /agent spawn <task>            Spawn agent'));
      console.log(chalk.gray('  /config show                   Show CLI config'));
      console.log(chalk.gray('  /remote on|off                 Enable/disable Remote Terminal'));
      console.log(chalk.gray('  /confirm on|off                Enable/disable local confirmation'));
      console.log(chalk.gray('  /allow <prefix|*>              Add remote allow rule'));
      console.log(chalk.gray('  /allow-clear                   Clear remote allow rules'));
      console.log(chalk.gray('  /clear                         Clear screen'));
      console.log(chalk.gray('  /exit                          Exit chat\n'));
    };

    const handleSlashCommand = async (input: string): Promise<boolean> => {
      const trimmed = input.trim();
      if (!trimmed.startsWith('/')) return false;

      const parts = trimmed.slice(1).split(' ').filter(Boolean);
      const cmd = (parts[0] || '').toLowerCase();
      const rest = parts.slice(1);

      if (cmd === 'help') {
        showHelp();
        return true;
      }

      if (cmd === 'exit') {
        rl.close();
        return true;
      }

      if (cmd === 'clear') {
        process.stdout.write('\x1Bc');
        return true;
      }

      if (cmd === 'whoami') {
        const me = await api.whoami();
        console.log(chalk.green(`\nYou are: ${me.user.email} (${me.user.role})\n`));
        return true;
      }

      if (cmd === 'config' && rest[0]?.toLowerCase() === 'show') {
        const all = config.getAll();
        console.log(chalk.bold('\nCLI Config'));
        console.log(chalk.gray(`API URL: ${all.apiUrl || '(not set)'}`));
        console.log(chalk.gray(`API Token: ${all.apiToken ? '✓ Set' : '✗ Not set'}`));
        console.log(chalk.gray(`User ID: ${all.userId || '(not set)'}`));
        console.log(chalk.gray(`Device ID: ${all.deviceId || '(not set)'}`));
        console.log(chalk.gray(`Remote Terminal: ${all.remoteTerminalEnabled ? 'enabled' : 'disabled'}`));
        console.log(chalk.gray(`Remote Confirm: ${all.remoteTerminalRequireConfirm ? 'on' : 'off'}`));
        const allow = Array.isArray(all.remoteTerminalAllowedCommands) ? all.remoteTerminalAllowedCommands : [];
        console.log(chalk.gray(`Remote Allowlist: ${allow.length ? allow.join(', ') : '(none)'}`));
        console.log('');
        return true;
      }

      if (cmd === 'remote') {
        const mode = (rest[0] || '').toLowerCase();
        if (mode === 'on' || mode === 'enable' || mode === 'enabled') {
          config.set('remoteTerminalEnabled', true);
          await remoteTerminal.connect();
          console.log(chalk.green('\n✓ Remote Terminal enabled\n'));
          return true;
        }
        if (mode === 'off' || mode === 'disable' || mode === 'disabled') {
          config.set('remoteTerminalEnabled', false);
          remoteTerminal.disconnect();
          console.log(chalk.green('\n✓ Remote Terminal disabled\n'));
          return true;
        }
        console.log(chalk.red('\nInvalid. Use: /remote on|off\n'));
        return true;
      }

      if (cmd === 'confirm') {
        const mode = (rest[0] || '').toLowerCase();
        if (mode === 'on' || mode === 'enable' || mode === 'enabled') {
          config.set('remoteTerminalRequireConfirm', true);
          console.log(chalk.green('\n✓ Remote confirmation enabled\n'));
          return true;
        }
        if (mode === 'off' || mode === 'disable' || mode === 'disabled') {
          config.set('remoteTerminalRequireConfirm', false);
          console.log(chalk.green('\n✓ Remote confirmation disabled\n'));
          return true;
        }
        console.log(chalk.red('\nInvalid. Use: /confirm on|off\n'));
        return true;
      }

      if (cmd === 'allow') {
        const rule = rest.join(' ').trim();
        if (!rule) {
          console.log(chalk.red('\nUsage: /allow <prefix|*>\n'));
          return true;
        }
        const existing = config.get('remoteTerminalAllowedCommands');
        const list = Array.isArray(existing) ? existing.slice() : [];
        list.push(rule);
        config.set('remoteTerminalAllowedCommands', list);
        console.log(chalk.green(`\n✓ Added allow rule: ${rule}\n`));
        return true;
      }

      if (cmd === 'allow-clear') {
        config.set('remoteTerminalAllowedCommands', []);
        console.log(chalk.green('\n✓ Cleared allow rules\n'));
        return true;
      }

      if (cmd === 'shell') {
        const shellCmd = rest.join(' ').trim();
        if (!shellCmd) {
          console.log(chalk.red('\nUsage: /shell <command>\n'));
          return true;
        }
        const result = await api.executeShell(shellCmd);
        const exitCode = result?.result?.exitCode;
        const stdout = result?.result?.stdout;
        const stderr = result?.result?.stderr;
        console.log(chalk.bold('\nShell Result'));
        console.log(chalk.gray(`Exit Code: ${exitCode}`));
        if (stdout) {
          console.log(chalk.bold('STDOUT:'));
          console.log(stdout);
        }
        if (stderr) {
          console.log(chalk.bold.red('STDERR:'));
          console.error(stderr);
        }
        console.log('');
        return true;
      }

      if (cmd === 'code') {
        const objective = rest.join(' ').trim();
        if (!objective) {
          console.log(chalk.red('\nUsage: /code <objective>\n'));
          return true;
        }

        const enrichedObjective =
          `You are an autonomous coding agent working inside this repository. ` +
          `Goal: ${objective}\n` +
          `Rules: make minimal changes, keep code style, run tests/build, and report what changed. ` +
          `Use shell and file tools only if permissions allow.`;

        const response = await api.startMission(enrichedObjective);
        const mission = response.mission;
        console.log(chalk.green('\n✓ Coding mission started'));
        console.log(chalk.gray(`Mission ID: ${mission.id}`));
        console.log(chalk.gray(`Status: ${mission.status}`));
        console.log(chalk.gray('Watch it with:'));
        console.log(chalk.cyan(`  gitu mission watch ${mission.id}`));
        console.log('');
        return true;
      }

      if (cmd === 'notebooks') {
        const data = await api.listNotebooks();
        const notebooks = Array.isArray(data?.notebooks) ? data.notebooks : Array.isArray(data) ? data : [];
        console.log(chalk.bold('\nNotebooks'));
        for (const nb of notebooks) {
          console.log(chalk.gray(`- ${nb.id}: ${nb.title || nb.name || '(untitled)'}`));
        }
        console.log('');
        return true;
      }

      if (cmd === 'notebook') {
        const notebookId = rest[0];
        const question = rest.slice(1).join(' ').trim();
        if (!notebookId || !question) {
          console.log(chalk.red('\nUsage: /notebook <id> <question>\n'));
          return true;
        }
        const response = await api.queryNotebook(notebookId, question);
        const text = response?.answer || response?.content || JSON.stringify(response);
        console.log(`${chalk.green('\nGitu>')} ${text}\n`);
        return true;
      }

      if (cmd === 'agent') {
        const sub = (rest[0] || '').toLowerCase();
        if (sub === 'list') {
          const data = await api.listAgents();
          const agents = Array.isArray(data?.agents) ? data.agents : Array.isArray(data) ? data : [];
          console.log(chalk.bold('\nAgents'));
          for (const a of agents) {
            console.log(chalk.gray(`- ${a.id}: ${a.status || a.state || 'unknown'} ${a.task ? `(${a.task})` : ''}`));
          }
          console.log('');
          return true;
        }
        if (sub === 'spawn') {
          const task = rest.slice(1).join(' ').trim();
          if (!task) {
            console.log(chalk.red('\nUsage: /agent spawn <task>\n'));
            return true;
          }
          const data = await api.spawnAgent(task);
          const id = data?.agentId || data?.id || data?.agent?.id;
          console.log(chalk.green(`\n✓ Agent spawned: ${id || '(unknown id)'}\n`));
          return true;
        }
        console.log(chalk.red('\nUsage: /agent list | /agent spawn <task>\n'));
        return true;
      }

      console.log(chalk.red('\nUnknown command. Type /help\n'));
      return true;
    };

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
        const handled = await handleSlashCommand(input);
        if (handled) {
          rl.prompt();
          return;
        }

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
