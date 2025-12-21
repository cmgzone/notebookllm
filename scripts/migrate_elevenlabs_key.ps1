# Migrate ElevenLabs API Key to Neon Database
# This script stores your ElevenLabs API key securely in the encrypted database

Write-Host "=== ElevenLabs API Key Migration ===" -ForegroundColor Cyan
Write-Host ""

# Check if .env exists
if (-not (Test-Path ".env")) {
    Write-Host "Error: .env file not found" -ForegroundColor Red
    Write-Host "Please create a .env file with your ELEVENLABS_API_KEY" -ForegroundColor Yellow
    exit 1
}

# Read .env file
$envContent = Get-Content ".env" -Raw
$elevenLabsKey = ""

# Extract ElevenLabs API key
if ($envContent -match 'ELEVENLABS_API_KEY=(.+)') {
    $elevenLabsKey = $matches[1].Trim()
}

if ([string]::IsNullOrWhiteSpace($elevenLabsKey)) {
    Write-Host "No ELEVENLABS_API_KEY found in .env file" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Please enter your ElevenLabs API key:" -ForegroundColor Cyan
    $elevenLabsKey = Read-Host
}

if ([string]::IsNullOrWhiteSpace($elevenLabsKey)) {
    Write-Host "Error: No API key provided" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "Found ElevenLabs API key: $($elevenLabsKey.Substring(0, [Math]::Min(10, $elevenLabsKey.Length)))..." -ForegroundColor Green
Write-Host ""

# Check for Neon credentials
$neonHost = ""
$neonDb = ""
$neonUser = ""
$neonPass = ""

if ($envContent -match 'NEON_HOST=(.+)') { $neonHost = $matches[1].Trim() }
if ($envContent -match 'NEON_DATABASE=(.+)') { $neonDb = $matches[1].Trim() }
if ($envContent -match 'NEON_USERNAME=(.+)') { $neonUser = $matches[1].Trim() }
if ($envContent -match 'NEON_PASSWORD=(.+)') { $neonPass = $matches[1].Trim() }

if ([string]::IsNullOrWhiteSpace($neonHost) -or [string]::IsNullOrWhiteSpace($neonDb)) {
    Write-Host "Error: Neon database credentials not found in .env" -ForegroundColor Red
    Write-Host "Please configure your Neon database first" -ForegroundColor Yellow
    exit 1
}

# Store the key directly (GlobalCredentialsService handles raw keys as fallback)
$encryptedKey = $elevenLabsKey

Write-Host "Connecting to Neon database..." -ForegroundColor Cyan

# Create SQL to insert encrypted key
$sql = @"
INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
VALUES ('elevenlabs', '$encryptedKey', 'ElevenLabs TTS API Key', CURRENT_TIMESTAMP)
ON CONFLICT (service_name) 
DO UPDATE SET encrypted_value = '$encryptedKey', description = 'ElevenLabs TTS API Key', updated_at = CURRENT_TIMESTAMP;
"@

# Save SQL to temp file
$sqlFile = "temp_elevenlabs_migration.sql"
$sql | Out-File -FilePath $sqlFile -Encoding UTF8

Write-Host "Executing migration..." -ForegroundColor Cyan

# Execute using psql if available
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue

if ($psqlPath) {
    $env:PGPASSWORD = $neonPass
    psql -h $neonHost -U $neonUser -d $neonDb -f $sqlFile
    Remove-Item $sqlFile
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ ElevenLabs API key migrated successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Your API key is now stored securely in the database." -ForegroundColor Cyan
        Write-Host "The app will automatically use the encrypted key from the database." -ForegroundColor Cyan
    } else {
        Write-Host ""
        Write-Host "Error: Migration failed" -ForegroundColor Red
        Write-Host "Please check your database connection" -ForegroundColor Yellow
    }
} else {
    Write-Host ""
    Write-Host "psql not found. Please run this SQL manually:" -ForegroundColor Yellow
    Write-Host ""
    Write-Host $sql -ForegroundColor White
    Write-Host ""
    Remove-Item $sqlFile
}

Write-Host ""
Write-Host "Done!" -ForegroundColor Green
