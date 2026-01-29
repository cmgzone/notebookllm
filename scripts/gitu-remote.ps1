# Gitu Remote CLI Helper for Windows
# Usage: .\gitu-remote.ps1 <command> [args]
# Example: .\gitu-remote.ps1 help
# Example: .\gitu-remote.ps1 generate-qr user-123

param(
    [Parameter(Position=0, Mandatory=$false)]
    [string]$Command = "help",
    
    [Parameter(Position=1, ValueFromRemainingArguments=$true)]
    [string[]]$Args
)

# Configuration - Update these values
$COOLIFY_HOST = "your-coolify-server.com"
$COOLIFY_USER = "your-ssh-user"
$CONTAINER_NAME = "notebookllm-backend"

Write-Host "🔍 Connecting to Coolify server..." -ForegroundColor Cyan

# Find container ID
$findContainerCmd = "docker ps --filter 'name=$CONTAINER_NAME' --format '{{.ID}}' | head -1"
$CONTAINER_ID = ssh "$COOLIFY_USER@$COOLIFY_HOST" $findContainerCmd

if ([string]::IsNullOrWhiteSpace($CONTAINER_ID)) {
    Write-Host "❌ Error: Container '$CONTAINER_NAME' not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Available containers:" -ForegroundColor Yellow
    ssh "$COOLIFY_USER@$COOLIFY_HOST" "docker ps --format 'table {{.Names}}\t{{.Status}}'"
    exit 1
}

Write-Host "✅ Found container: $CONTAINER_ID" -ForegroundColor Green

# Build command
$gituCommand = "npm run gitu-cli -- $Command"
if ($Args) {
    $gituCommand += " " + ($Args -join " ")
}

Write-Host "🚀 Executing: $gituCommand" -ForegroundColor Cyan
Write-Host ""

# Execute command
$execCmd = "docker exec -it $CONTAINER_ID $gituCommand"
ssh "$COOLIFY_USER@$COOLIFY_HOST" $execCmd

if ($LASTEXITCODE -ne 0) {
    Write-Host ""
    Write-Host "❌ Command failed with exit code: $LASTEXITCODE" -ForegroundColor Red
    exit $LASTEXITCODE
}

Write-Host ""
Write-Host "✅ Command completed successfully" -ForegroundColor Green
