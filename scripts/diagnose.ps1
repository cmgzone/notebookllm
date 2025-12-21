# Diagnostic Script for Notebook LLM
# Run this to check if everything is configured correctly

Write-Host "🔍 Notebook LLM Diagnostic Tool" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

# Check 1: Supabase CLI
Write-Host "1. Checking Supabase CLI..." -ForegroundColor Yellow
try {
    $version = supabase --version 2>&1
    Write-Host "   ✅ Supabase CLI installed: $version" -ForegroundColor Green
} catch {
    Write-Host "   ❌ Supabase CLI not found!" -ForegroundColor Red
    Write-Host "   Install with: npm install -g supabase" -ForegroundColor Yellow
    exit 1
}

# Check 2: Project Link
Write-Host "`n2. Checking project link..." -ForegroundColor Yellow
try {
    $status = supabase status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "   ✅ Project is linked" -ForegroundColor Green
    } else {
        Write-Host "   ❌ Project not linked!" -ForegroundColor Red
        Write-Host "   Run: supabase link --project-ref ndwovuxiuzbdhdqwpaau" -ForegroundColor Yellow
        exit 1
    }
} catch {
    Write-Host "   ❌ Project not linked!" -ForegroundColor Red
    Write-Host "   Run: supabase link --project-ref ndwovuxiuzbdhdqwpaau" -ForegroundColor Yellow
    exit 1
}

# Check 3: Deployed Functions
Write-Host "`n3. Checking deployed functions..." -ForegroundColor Yellow
try {
    $functions = supabase functions list 2>&1
    if ($functions -match "web_search") {
        Write-Host "   ✅ Functions are deployed" -ForegroundColor Green
        Write-Host "   Functions found:" -ForegroundColor Gray
        Write-Host "   $functions" -ForegroundColor Gray
    } else {
        Write-Host "   ❌ Functions not deployed!" -ForegroundColor Red
        Write-Host "   Run: supabase functions deploy" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Could not check functions" -ForegroundColor Red
}

# Check 4: Secrets
Write-Host "`n4. Checking secrets..." -ForegroundColor Yellow
try {
    $secrets = supabase secrets list 2>&1
    Write-Host "   Current secrets:" -ForegroundColor Gray
    Write-Host "   $secrets" -ForegroundColor Gray
    
    $requiredSecrets = @(
        "SUPABASE_SERVICE_ROLE_KEY",
        "SERPER_API_KEY"
    )
    
    $optionalSecrets = @(
        "GEMINI_API_KEY",
        "OPENAI_API_KEY"
    )
    
    $missingSecrets = @()
    foreach ($secret in $requiredSecrets) {
        if ($secrets -notmatch $secret) {
            $missingSecrets += $secret
        }
    }
    
    if ($missingSecrets.Count -eq 0) {
        Write-Host "   ✅ All required secrets are set" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Missing required secrets:" -ForegroundColor Yellow
        foreach ($secret in $missingSecrets) {
            Write-Host "      - $secret" -ForegroundColor Red
        }
        Write-Host "   Set with: supabase secrets set SECRET_NAME=value" -ForegroundColor Yellow
    }
    
    # Check for AI provider (Gemini or OpenAI)
    $hasGemini = $secrets -match "GEMINI_API_KEY"
    $hasOpenAI = $secrets -match "OPENAI_API_KEY"
    
    if ($hasGemini -or $hasOpenAI) {
        if ($hasGemini) {
            Write-Host "   ✅ Using Gemini for AI" -ForegroundColor Green
        }
        if ($hasOpenAI) {
            Write-Host "   ✅ Using OpenAI for AI" -ForegroundColor Green
        }
    } else {
        Write-Host "   ❌ No AI provider configured!" -ForegroundColor Red
        Write-Host "   Set either GEMINI_API_KEY or OPENAI_API_KEY" -ForegroundColor Yellow
    }
} catch {
    Write-Host "   ❌ Could not check secrets" -ForegroundColor Red
}

# Check 5: .env file
Write-Host "`n5. Checking .env file..." -ForegroundColor Yellow
if (Test-Path ".env") {
    Write-Host "   ✅ .env file exists" -ForegroundColor Green
    $envContent = Get-Content ".env" -Raw
    
    $requiredEnvVars = @(
        "SUPABASE_URL",
        "SUPABASE_ANON_KEY",
        "SUPABASE_FUNCTIONS_URL"
    )
    
    $missingEnvVars = @()
    foreach ($var in $requiredEnvVars) {
        if ($envContent -notmatch $var) {
            $missingEnvVars += $var
        }
    }
    
    if ($missingEnvVars.Count -eq 0) {
        Write-Host "   ✅ All required environment variables are set" -ForegroundColor Green
    } else {
        Write-Host "   ⚠️  Missing environment variables:" -ForegroundColor Yellow
        foreach ($var in $missingEnvVars) {
            Write-Host "      - $var" -ForegroundColor Red
        }
    }
} else {
    Write-Host "   ❌ .env file not found!" -ForegroundColor Red
    Write-Host "   Create .env file with Supabase credentials" -ForegroundColor Yellow
}

# Check 6: Test Function
Write-Host "`n6. Testing web_search function..." -ForegroundColor Yellow
try {
    $anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5kd292dXhpdXpiZGhkcXdwYWF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyODY5NjUsImV4cCI6MjA3ODg2Mjk2NX0.d992B3cr0DlonC4AMGJD1mUCukWv_jg-55AJlI16NGo"
    $url = "https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1/web_search"
    
    $headers = @{
        "Authorization" = "Bearer $anonKey"
        "Content-Type" = "application/json"
    }
    
    $body = @{
        q = "test"
    } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "   ✅ web_search function is working!" -ForegroundColor Green
} catch {
    Write-Host "   ❌ web_search function failed!" -ForegroundColor Red
    Write-Host "   Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "   This is likely why your app is showing errors" -ForegroundColor Yellow
}

# Summary
Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "📊 Diagnostic Summary" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. If functions not deployed: supabase functions deploy" -ForegroundColor White
Write-Host "2. If secrets missing: supabase secrets set SECRET_NAME=value" -ForegroundColor White
Write-Host "3. If .env missing: Create .env file with Supabase credentials" -ForegroundColor White
Write-Host "4. If web_search fails: Check function logs with: supabase functions logs web_search" -ForegroundColor White

Write-Host "`n✨ Diagnostic complete!" -ForegroundColor Green
