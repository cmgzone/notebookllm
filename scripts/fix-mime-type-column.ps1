#!/usr/bin/env pwsh

Write-Host "🔧 Fixing mime_type column issue..." -ForegroundColor Yellow

# Change to backend directory
Set-Location backend

# Check if we're in the right directory
if (-not (Test-Path "src/scripts/run-mime-type-migration.ts")) {
    Write-Host "❌ Error: Migration script not found. Make sure you're in the project root." -ForegroundColor Red
    exit 1
}

# Run the migration
Write-Host "Running mime_type migration..." -ForegroundColor Blue
try {
    npx tsx src/scripts/run-mime-type-migration.ts
    Write-Host "✅ Migration completed successfully!" -ForegroundColor Green
} catch {
    Write-Host "❌ Migration failed: $_" -ForegroundColor Red
    exit 1
}

# Go back to project root
Set-Location ..

Write-Host "🚀 mime_type column fix complete! Your ingestion should work now." -ForegroundColor Green