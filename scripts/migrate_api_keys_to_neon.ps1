# PowerShell script to migrate API keys from .env to Neon database (encrypted)

Write-Host "=== Migrate API Keys to Neon Database ===" -ForegroundColor Cyan
Write-Host ""

# Load .env file
$envFile = ".env"
if (Test-Path $envFile) {
    $envVars = @{}
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^([^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            $envVars[$key] = $value
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
    Write-Host "✓ Loaded .env file" -ForegroundColor Green
} else {
    Write-Host "✗ .env file not found" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "API Keys found in .env:" -ForegroundColor Yellow
Write-Host "  - GEMINI_API_KEY: $($envVars['GEMINI_API_KEY'].Substring(0, [Math]::Min(20, $envVars['GEMINI_API_KEY'].Length)))..." -ForegroundColor Gray
Write-Host "  - ELEVENLABS_API_KEY: $($envVars['ELEVENLABS_API_KEY'].Substring(0, [Math]::Min(20, $envVars['ELEVENLABS_API_KEY'].Length)))..." -ForegroundColor Gray
Write-Host "  - SERPER_API_KEY: $($envVars['SERPER_API_KEY'].Substring(0, [Math]::Min(20, $envVars['SERPER_API_KEY'].Length)))..." -ForegroundColor Gray
Write-Host ""

Write-Host "Step 1: Create the api_keys table in Neon" -ForegroundColor Cyan
Write-Host "Run this SQL in Neon Console (https://console.neon.tech):" -ForegroundColor Yellow
Write-Host ""
Write-Host @"
CREATE TABLE IF NOT EXISTS api_keys (
  service_name TEXT PRIMARY KEY,
  encrypted_value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
"@ -ForegroundColor Gray
Write-Host ""

Write-Host "Step 2: Run your Flutter app and execute this code:" -ForegroundColor Cyan
Write-Host @"
// In your app (e.g., in main.dart or a settings screen):
final credService = ref.read(globalCredentialsServiceProvider);

// Migrate all keys from .env
await credService.migrateFromEnv({
  'GEMINI_API_KEY': dotenv.env['GEMINI_API_KEY'] ?? '',
  'ELEVENLABS_API_KEY': dotenv.env['ELEVENLABS_API_KEY'] ?? '',
  'SERPER_API_KEY': dotenv.env['SERPER_API_KEY'] ?? '',
});
"@ -ForegroundColor Gray
Write-Host ""

Write-Host "Step 3: Verify keys are stored" -ForegroundColor Cyan
Write-Host "Run this SQL in Neon Console:" -ForegroundColor Yellow
Write-Host "SELECT service_name, description, updated_at FROM api_keys;" -ForegroundColor Gray
Write-Host ""

Write-Host "✓ Instructions complete!" -ForegroundColor Green
Write-Host ""
Write-Host "After migration, your app will use encrypted keys from Neon database" -ForegroundColor Cyan
Write-Host "instead of the .env file." -ForegroundColor Cyan
