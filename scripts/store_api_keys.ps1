# PowerShell script to store API keys in Neon database (encrypted)
# This will be done through the app, but this shows the process

Write-Host "=== Store API Keys in Neon Database ===" -ForegroundColor Cyan
Write-Host ""

# Load .env file
$envFile = ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
    Write-Host "✓ Loaded .env file" -ForegroundColor Green
} else {
    Write-Host "✗ .env file not found" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "API Keys to be stored (encrypted):" -ForegroundColor Yellow
Write-Host "  - GEMINI_API_KEY: $($env:GEMINI_API_KEY.Substring(0, 20))..." -ForegroundColor Gray
Write-Host "  - ELEVENLABS_API_KEY: $($env:ELEVENLABS_API_KEY.Substring(0, 20))..." -ForegroundColor Gray
Write-Host "  - SERPER_API_KEY: $($env:SERPER_API_KEY.Substring(0, 20))..." -ForegroundColor Gray
Write-Host ""

Write-Host "These keys will be encrypted and stored in Neon database" -ForegroundColor Cyan
Write-Host "when you first use the app after logging in." -ForegroundColor Cyan
Write-Host ""
Write-Host "The app will automatically:" -ForegroundColor Yellow
Write-Host "  1. Encrypt keys using AES-256" -ForegroundColor Gray
Write-Host "  2. Store in user_credentials table" -ForegroundColor Gray
Write-Host "  3. Retrieve and decrypt when needed" -ForegroundColor Gray
Write-Host ""
Write-Host "✓ Setup complete!" -ForegroundColor Green
