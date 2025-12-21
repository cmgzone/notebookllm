# PowerShell script to manually add OpenRouter API key to Neon

Write-Host "=== Add OpenRouter API Key to Neon ===" -ForegroundColor Cyan
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

$openrouterKey = $env:OPENROUTER_API_KEY

if (-not $openrouterKey -or $openrouterKey -eq 'your_openrouter_key_here') {
    Write-Host "✗ OpenRouter API key not found in .env" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please add your OpenRouter API key to .env file:" -ForegroundColor Yellow
    Write-Host "OPENROUTER_API_KEY=sk-or-v1-your-key-here" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Get your free API key from: https://openrouter.ai/keys" -ForegroundColor Cyan
    exit 1
}

Write-Host "Found OpenRouter API key: $($openrouterKey.Substring(0, 20))..." -ForegroundColor Green
Write-Host ""

# Encrypt the key
Write-Host "Encrypting API key..." -ForegroundColor Yellow

function Encrypt-ApiKey {
    param([string]$value)
    
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
    
    $combined = $iv + $encryptedBytes
    $base64 = [Convert]::ToBase64String($combined)
    
    return $base64
}

$encryptedKey = Encrypt-ApiKey $openrouterKey
Write-Host "✓ Key encrypted" -ForegroundColor Green
Write-Host ""

# Create SQL
$sql = @"
-- Add OpenRouter API key (encrypted)
INSERT INTO api_keys (service_name, encrypted_value, description, updated_at)
VALUES ('openrouter', '$encryptedKey', 'OpenRouter API Key', CURRENT_TIMESTAMP)
ON CONFLICT (service_name) 
DO UPDATE SET encrypted_value = EXCLUDED.encrypted_value, updated_at = CURRENT_TIMESTAMP;

-- Verify
SELECT service_name, description, updated_at FROM api_keys WHERE service_name = 'openrouter';
"@

Write-Host "=== SQL to run in Neon Console ===" -ForegroundColor Cyan
Write-Host ""
Write-Host $sql -ForegroundColor Gray
Write-Host ""

# Save to file
$sqlFile = "add_openrouter_key_encrypted.sql"
$sql | Out-File -FilePath $sqlFile -Encoding UTF8

Write-Host "✓ SQL saved to: $sqlFile" -ForegroundColor Green
Write-Host ""
Write-Host "Next steps:" -ForegroundColor Yellow
Write-Host "1. Go to https://console.neon.tech" -ForegroundColor Gray
Write-Host "2. Open SQL Editor" -ForegroundColor Gray
Write-Host "3. Copy and paste the SQL from $sqlFile" -ForegroundColor Gray
Write-Host "4. Click 'Run'" -ForegroundColor Gray
Write-Host ""
Write-Host "Or use the QuickDeployKeys screen in your app for automatic deployment" -ForegroundColor Cyan
