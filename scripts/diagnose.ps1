Write-Host "🔍 Notebook LLM Diagnostic Tool" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan
Write-Host "1. Environment checks..." -ForegroundColor Yellow
try {
  $node = node -v 2>&1
  $npm = npm -v 2>&1
  Write-Host "   ✅ Node: $node, NPM: $npm" -ForegroundColor Green
} catch {
  Write-Host "   ❌ Node/NPM not available" -ForegroundColor Red
}
Write-Host "`n2. .env configuration..." -ForegroundColor Yellow
if (Test-Path ".env") {
  Write-Host "   ✅ .env file exists" -ForegroundColor Green
  $envContent = Get-Content ".env" -Raw
  $requiredEnvVars = @(
    "DATABASE_URL",
    "JWT_SECRET"
  )
  $optionalEnvVars = @(
    "GEMINI_API_KEY",
    "OPENAI_API_KEY",
    "SERPER_API_KEY"
  )
  $missingEnvVars = @()
  foreach ($var in $requiredEnvVars) {
    if ($envContent -notmatch $var) {
      $missingEnvVars += $var
    }
  }
  if ($missingEnvVars.Count -eq 0) {
    Write-Host "   ✅ Required env vars are set" -ForegroundColor Green
  } else {
    Write-Host "   ⚠️ Missing env vars:" -ForegroundColor Yellow
    foreach ($var in $missingEnvVars) {
      Write-Host "      - $var" -ForegroundColor Red
    }
  }
  $aiSet = ($envContent -match "GEMINI_API_KEY") -or ($envContent -match "OPENAI_API_KEY")
  if ($aiSet) {
    if ($envContent -match "GEMINI_API_KEY") { Write-Host "   ✅ Using Gemini" -ForegroundColor Green }
    if ($envContent -match "OPENAI_API_KEY") { Write-Host "   ✅ Using OpenAI" -ForegroundColor Green }
  } else {
    Write-Host "   ⚠️ No AI provider configured" -ForegroundColor Yellow
  }
} else {
  Write-Host "   ❌ .env file not found" -ForegroundColor Red
}
Write-Host "`n3. Backend health..." -ForegroundColor Yellow
try {
  $port = $env:PORT
  if (-not $port) { $port = 3000 }
  $healthUrl = "http://localhost:$port/api/health"
  $resp = Invoke-RestMethod -Uri $healthUrl -Method Get -ErrorAction Stop
  if ($resp.status -eq "ok") {
    Write-Host "   ✅ Backend responding on port $port" -ForegroundColor Green
  } else {
    Write-Host "   ⚠️ Backend responded with unexpected payload" -ForegroundColor Yellow
  }
} catch {
  Write-Host "   ❌ Backend not responding on configured port" -ForegroundColor Red
}
Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "📊 Diagnostic Summary" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan
Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Ensure DATABASE_URL and JWT_SECRET are set" -ForegroundColor White
Write-Host "2. Set GEMINI_API_KEY or OPENAI_API_KEY if using AI" -ForegroundColor White
Write-Host "3. Start backend and verify /api/health responds" -ForegroundColor White
Write-Host "`n✨ Diagnostic complete!" -ForegroundColor Green
