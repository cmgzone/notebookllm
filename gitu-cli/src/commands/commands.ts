import chalk from 'chalk';

export class CommandsCommand {
  static show() {
    console.log(chalk.bold('\nGitu CLI Commands\n'));
    console.log(chalk.cyan('Main:'));
    console.log(chalk.gray('  gitu init'));
    console.log(chalk.gray('  gitu onboard'));
    console.log(chalk.gray('  gitu auth <pairing-token>'));
    console.log(chalk.gray('  gitu chat'));
    console.log(chalk.gray('  gitu run "<shell command>"'));
    console.log(chalk.gray('  gitu notebook list'));
    console.log(chalk.gray('  gitu notebook query <notebook-id> "<question>"'));
    console.log(chalk.gray('  gitu agent list|spawn|watch'));
    console.log(chalk.gray('  gitu config show'));
    console.log(chalk.gray('  gitu permissions list|request|approve|revoke'));
    console.log(chalk.gray(''));
    console.log(chalk.cyan('Chat slash commands (inside: gitu chat):'));
    console.log(chalk.gray('  /help'));
    console.log(chalk.gray('  /whoami'));
    console.log(chalk.gray('  /shell <command>'));
    console.log(chalk.gray('  /code <objective>'));
    console.log(chalk.gray('  /notebooks'));
    console.log(chalk.gray('  /notebook <id> <question>'));
    console.log(chalk.gray('  /agent list'));
    console.log(chalk.gray('  /agent spawn <task>'));
    console.log(chalk.gray('  /config show'));
    console.log(chalk.gray('  /remote on|off'));
    console.log(chalk.gray('  /confirm on|off'));
    console.log(chalk.gray('  /allow <prefix|*>'));
    console.log(chalk.gray('  /allow-clear'));
    console.log(chalk.gray('  /clear'));
    console.log(chalk.gray('  /exit'));
    console.log('');
  }
}
