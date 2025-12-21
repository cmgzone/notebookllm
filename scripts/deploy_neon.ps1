# Deploy Database Schema and Functions to Neon
Write-Host "🚀 Deploying to Neon PostgreSQL..." -ForegroundColor Cyan

# Load environment variables
$envFile = ".env"
if (Test-Path $envFile) {
    Get-Content $envFile | ForEach-Object {
        if ($_ -match '^\s*([^#][^=]+)=(.*)$') {
            $key = $matches[1].Trim()
            $value = $matches[2].Trim()
            [Environment]::SetEnvironmentVariable($key, $value, "Process")
        }
    }
}

$host = $env:NEON_HOST
$database = $env:NEON_DATABASE
$username = $env:NEON_USERNAME
$password = $env:NEON_PASSWORD

if (-not $host -or -not $database -or -not $username -or -not $password) {
    Write-Host "❌ Error: Neon credentials not found in .env file" -ForegroundColor Red
    exit 1
}

Write-Host "📋 Connection Details:" -ForegroundColor Yellow
Write-Host "   Host: $host"
Write-Host "   Database: $database"
Write-Host ""

# Check if psql is available
$psqlCommand = Get-Command psql -ErrorAction SilentlyContinue

if ($psqlCommand) {
    Write-Host "✅ PostgreSQL client found" -ForegroundColor Green
    $env:PGPASSWORD = $password
    $connectionString = "postgresql://${username}:${password}@${host}/${database}?sslmode=require"
    
    Write-Host "📤 Executing SQL file..." -ForegroundColor Cyan
    psql $connectionString -f neon_complete_setup.sql
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Database deployed successfully!" -ForegroundColor Green
    }
}
else {
    Write-Host "⚠️  PostgreSQL client not found" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "📝 Use Neon Console instead:" -ForegroundColor Cyan
    Write-Host "   1. Opening Neon Console..." -ForegroundColor White
    Write-Host "   2. Go to SQL Editor"
    Write-Host "   3. Copy contents of 'neon_complete_setup.sql'"
    Write-Host "   4. Paste and click 'Run'"
    Write-Host ""
    
    Start-Process "https://console.neon.tech/app/projects"
    Write-Host "✅ Browser opened. Please run the SQL manually." -ForegroundColor Green
}

Write-Host ""
Write-Host "📄 SQL file: neon_complete_setup.sql" -ForegroundColor Yellow
