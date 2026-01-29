# Link Telegram Test Account Helper Script
param(
    [Parameter(Mandatory=$false)]
    [string]$TelegramUserId,
    [Parameter(Mandatory=$false)]
    [string]$Email
)

Write-Host "🔗 Telegram Account Linker" -ForegroundColor Cyan
Write-Host "=========================" -ForegroundColor Cyan
Write-Host ""

# Check if we're in the backend directory
if (-not (Test-Path "src/scripts/link-telegram-test-account.ts")) {
    Write-Host "❌ Error: This script must be run from the backend directory" -ForegroundColor Red
    Write-Host "   Current directory: $(Get-Location)" -ForegroundColor Yellow
    Write-Host "   Please run: cd backend" -ForegroundColor Yellow
    exit 1
}

# Check if .env file exists
if (-not (Test-Path ".env")) {
    Write-Host "❌ Error: .env file not found" -ForegroundColor Red
    Write-Host "   Please create a .env file with your database configuration" -ForegroundColor Yellow
    exit 1
}

# If no Telegram User ID provided, show instructions
if (-not $TelegramUserId) {
    Write-Host "📋 How to get your Telegram User ID:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "1. Make sure your Telegram bot is running (use .\test-telegram.ps1)" -ForegroundColor White
    Write-Host "2. Send a message to your bot on Telegram" -ForegroundColor White
    Write-Host "3. Look at the error message - it will show your chat ID" -ForegroundColor White
    Write-Host "4. Run this script again with that ID:" -ForegroundColor White
    Write-Host ""
    Write-Host "   .\link-telegram.ps1 <your_telegram_user_id>" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "   Example: .\link-telegram.ps1 123456789" -ForegroundColor Cyan
    Write-Host "   Or with email: .\link-telegram.ps1 123456789 test@example.com" -ForegroundColor Cyan
    Write-Host ""
    exit 0
}

Write-Host "🚀 Linking Telegram account: $TelegramUserId" -ForegroundColor Green

if ($Email) {
    Write-Host "📧 Using email: $Email" -ForegroundColor Green
    npx tsx src/scripts/link-telegram-test-account.ts $TelegramUserId $Email
} else {
    Write-Host "📧 No email provided - will use existing user or create default" -ForegroundColor Yellow
    npx tsx src/scripts/link-telegram-test-account.ts $TelegramUserId
}

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "✅ Success! Your Telegram account is now linked." -ForegroundColor Green
    Write-Host ""
    Write-Host "🎉 Next steps:" -ForegroundColor Cyan
    Write-Host "   1. Make sure your bot is running: .\test-telegram.ps1" -ForegroundColor White
    Write-Host "   2. Send a message to your bot on Telegram" -ForegroundColor White
    Write-Host "   3. The bot should now respond!" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "❌ Failed to link Telegram account" -ForegroundColor Red
    Write-Host "   Check the error message above for details" -ForegroundColor Yellow
    Write-Host ""
}
