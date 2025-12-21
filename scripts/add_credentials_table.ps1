# PowerShell script to add credentials table to Neon database

Write-Host "=== Adding Credentials Table to Neon ===" -ForegroundColor Cyan
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

$host = $env:NEON_HOST
$database = $env:NEON_DATABASE
$username = $env:NEON_USERNAME
$password = $env:NEON_PASSWORD

if (-not $host -or -not $database -or -not $username -or -not $password) {
    Write-Host "✗ Missing Neon credentials in .env" -ForegroundColor Red
    exit 1
}

Write-Host "Neon Database: $database" -ForegroundColor Gray
Write-Host ""

# Read SQL file
$sqlFile = "add_credentials_table.sql"
if (-not (Test-Path $sqlFile)) {
    Write-Host "✗ SQL file not found: $sqlFile" -ForegroundColor Red
    exit 1
}

$sql = Get-Content $sqlFile -Raw

Write-Host "Executing SQL..." -ForegroundColor Yellow
Write-Host ""

# Use psql if available
$psqlPath = Get-Command psql -ErrorAction SilentlyContinue

if ($psqlPath) {
    $env:PGPASSWORD = $password
    $connectionString = "postgresql://${username}@${host}/${database}?sslmode=require"
    
    $sql | psql $connectionString
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host ""
        Write-Host "✓ Credentials table added successfully!" -ForegroundColor Green
    } else {
        Write-Host ""
        Write-Host "✗ Failed to execute SQL" -ForegroundColor Red
        exit 1
    }
} else {
    Write-Host "psql not found. Please install PostgreSQL client or use Neon Console." -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Alternative: Copy the SQL from add_credentials_table.sql" -ForegroundColor Cyan
    Write-Host "and run it in Neon Console SQL Editor:" -ForegroundColor Cyan
    Write-Host "https://console.neon.tech" -ForegroundColor Blue
    Write-Host ""
    Write-Host "SQL to run:" -ForegroundColor Yellow
    Write-Host $sql -ForegroundColor Gray
}
