# Telegram Adapter Test Script
# This script helps you test the Telegram adapter

Write-Host "🤖 Telegram Adapter Test Helper" -ForegroundColor Cyan
Write-Host ""

# Check if TELEGRAM_BOT_TOKEN exists in .env
$envFile = ".env"
$tokenExists = $false

if (Test-Path $envFile) {
    $content = Get-Content $envFile
    $tokenExists = $content -match "TELEGRAM_BOT_TOKEN="
}

if (-not $tokenExists) {
    Write-Host "❌ TELEGRAM_BOT_TOKEN not found in .env file" -ForegroundColor Red
    Write-Host ""
    Write-Host "To get a Telegram bot token:" -ForegroundColor Yellow
    Write-Host "1. Open Telegram and search for @BotFather" -ForegroundColor White
    Write-Host "2. Send /newbot and follow the instructions" -ForegroundColor White
    Write-Host "3. Copy the bot token you receive" -ForegroundColor White
    Write-Host "4. Add this line to backend/.env:" -ForegroundColor White
    Write-Host "   TELEGRAM_BOT_TOKEN=your_token_here" -ForegroundColor Green
    Write-Host ""
    
    $response = Read-Host "Do you have a bot token to add now? (y/n)"
    
    if ($response -eq "y" -or $response -eq "Y") {
        $token = Read-Host "Enter your Telegram bot token"
        
        if ($token) {
            Add-Content -Path $envFile -Value "`nTELEGRAM_BOT_TOKEN=$token"
            Write-Host "✅ Token added to .env file!" -ForegroundColor Green
            Write-Host ""
        }
    } else {
        Write-Host ""
        Write-Host "Please add the token to .env and run this script again." -ForegroundColor Yellow
        exit 1
    }
}

Write-Host "📡 Starting Telegram adapter test..." -ForegroundColor Cyan
Write-Host ""

# Run the test script
npx tsx src/scripts/test-telegram-adapter.ts
