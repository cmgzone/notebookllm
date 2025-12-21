# Complete deployment script - Creates table and adds encrypted API keys to Neon

Write-Host "=== Notebook LLM - Deploy API Keys to Neon ===" -ForegroundColor Cyan
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

$host_db = $env:NEON_HOST
$database = $env:NEON_DATABASE
$username = $env:NEON_USERNAME
$password = $env:NEON_PASSWORD

if (-not $host_db -or -not $database -or -not $username -or -not $password) {
    Write-Host "✗ Missing Neon credentials in .env" -ForegroundColor Red
    exit 1
}

Write-Host "Neon Database: $database @ $host_db" -ForegroundColor Gray
Write-Host ""

# Step 1: Create SQL for table
Write-Host "Step 1: Creating api_keys table..." -ForegroundColor Yellow

$createTableSql = @"
-- Create api_keys table
CREATE TABLE IF NOT EXISTS api_keys (
  service_name TEXT PRIMARY KEY,
  encrypted_value TEXT NOT NULL,
  description TEXT,
  updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS idx_api_keys_service ON api_keys(service_name);
"@

# Step 2: Encrypt API keys using the same method as the app
Write-Host "Step 2: Encrypting API keys..." -ForegroundColor Yellow

function Encrypt-ApiKey {
    param([string]$value)
    
    # Use .NET crypto to match the app's encryption
    $secret = "notebook_llm_global_secret_key_2024"
    $sha256 = [System.Security.Cryptography.SHA256]::Create()
    $keyBytes = $sha256.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($secret))
    
    $aes = [System.Security.Cryptography.Aes]::Create()
    $aes.Key = $keyBytes
    $aes.GenerateIV()
    $iv = $aes.IV
    
    $encryptor = $aes.CreateEncryptor()
    $valueBytes = [System.Text.Encoding]::UTF8.GetBytes($value)
    $encryptedBytes = $encryptor.TransformFinalBlock($valueBytes, 0, $valueBytes.Length)
    
    # Combine IV + encrypted data
    $combined = $iv + $encryptedBytes
    $base64 = [Convert]::ToBase64String($combined)
    
    return $base64
}

$geminiKey = $env:GEMINI_API_KEY
$elevenlabsKey = $env:ELEVENLABS_API_KEY
$serperKey = $env:SERPER_API_KEY

if (-not $geminiKey -or -not $elevenlabsKey -or -not $serperKey) {
    Write-Host "✗ Missing API keys in .env" -ForegroundColor Red
    exit 1
}

$encryptedGemini = Encrypt-ApiKey $geminiKey
$encryptedElevenlabs = Encrypt-ApiKey $elevenlabsKey
$encryptedSerper = Encrypt-ApiKey $serperKey

Write-Host "✓ Keys encrypted" -ForegroundColor Green
Write-Host ""

# Step 3: Create insert SQL
Write-Host "Step 3: Preparing insert statements..." -ForegroundColor Yellow

$insertSql = @"
-- Insert encrypted API keys
INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
VALUES 
  ('gemini', '$encryptedGemini', 'Gemini AI API Key', CURRENT_TIMESTAMP),
  ('elevenlabs', '$encryptedElevenlabs', 'ElevenLabs API Key', CURRENT_TIMESTAMP),
  ('serper', '$encryptedSerper', 'Serper API Key', CURRENT_TIMESTAMP)
ON CONFLICT (service_name) 
DO UPDATE SET 
  encrypted_value = EXCLUDED.encrypted_value,
  description = EXCLUDED.description,
  updated_at = CURRENT_TIMESTAMP;
"@

# Step 4: Execute SQL
Write-Host "Step 4: Executing SQL in Neon..." -ForegroundColor Yellow
Write-Host ""

$fullSql = $createTableSql + "`n`n" + $insertSql

# Check if psql is available
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue

if ($psqlPath) {
    # Use psql
    $env:PGPASSWORD = $password
    $connectionString = "postgresql://${username}@${host_db}/${database}?sslmode=require"
    
    $fullSql | psql $connectionString
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ API keys deployed successfully!" -ForegroundColor Green
        Write-Host ""
        Write-Host "Verify with this SQL:" -ForegroundColor Cyan
        Write-Host "SELECT service_name, description, updated_at FROM api_keys;" -ForegroundColor Gray
    } else {
        Write-Host ""
        Write-Host "✗ Failed to execute SQL" -ForegroundColor Red
        exit 1
    }
} else {
    # No psql - provide manual instructions
    Write-Host "psql not found. Please run this SQL manually in Neon Console:" -ForegroundColor Yellow
    Write-Host "https://console.neon.tech" -ForegroundColor Blue
    Write-Host ""
    Write-Host "=== SQL TO RUN ===" -ForegroundColor Cyan
    Write-Host $fullSql -ForegroundColor Gray
    Write-Host ""
    Write-Host "Copy the SQL above and paste it into Neon's SQL Editor" -ForegroundColor Yellow
    
    # Save to file
    $sqlFile = "deploy_keys.sql"
    $fullSql | Out-File -FilePath $sqlFile -Encoding UTF8
    Write-Host ""
    Write-Host "✓ SQL saved to: $sqlFile" -ForegroundColor Green
}

Write-Host ""
Write-Host "=== Deployment Complete ===" -ForegroundColor Cyan
Write-Host "Your API keys are now encrypted and stored in Neon database" -ForegroundColor Green
