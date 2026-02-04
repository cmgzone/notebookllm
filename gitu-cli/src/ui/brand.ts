import chalk from 'chalk';

export function renderBrand(): string {
  const logo = [
    '   ______  __  ______  __  __',
    '  / ____/ / / /_  __/ / / / /',
    ' / / __  / /   / /   / / / /',
    '/ /_/ / / /___/ /   / /_/ /',
    '\\____/ /_____/ /_/   \\____/',
  ].join('\n');

  const tagline = 'Local-first assistant • Remote terminal ready';
  return `${chalk.cyanBright(logo)}\n${chalk.gray(tagline)}\n`;
}

export function printBrand(): void {
  console.log(renderBrand());
}
