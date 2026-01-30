import chalk from 'chalk';

export class AliasCommand {
  static show(shell: string = 'bash') {
    if (shell === 'powershell' || shell === 'pwsh') {
      console.log(`
# Gitu Shell Integration (PowerShell)
# Add this to your $PROFILE

function ?? {
    param(
        [Parameter(ValueFromRemainingArguments = $true)]
        $Query
    )
    $q = $Query -join " "
    gitu run $q
}

Write-Host "Gitu aliases loaded: use '?? <query>' to run commands" -ForegroundColor Cyan
`);
    } else {
      // Default to Bash/Zsh
      console.log(`
# Gitu Shell Integration (Bash/Zsh)
# Add this to your .bashrc or .zshrc

function ??() {
  gitu run "$*"
}

echo "Gitu aliases loaded: use '?? <query>' to run commands"
`);
    }
  }
}
