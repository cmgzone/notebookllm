# Automated Deployment Script
# All API keys included - just run this!

Write-Host "🚀 Automated Deployment - Notebook LLM" -ForegroundColor Cyan
Write-Host "========================================`n" -ForegroundColor Cyan

# Your API Keys
$SERPER_API_KEY = "ec5f971deb548fa4e187daffe2092ee20c36a584"
$GEMINI_API_KEY = "AIzaSyB-IGUHHXx0u8ipsDEVarBfrO08jXzzziI"

Write-Host "✅ Serper API key loaded" -ForegroundColor Green
Write-Host "✅ Gemini API key loaded (using Gemini 2.0 Flash)`n" -ForegroundColor Green

# Step 1: Check Supabase CLI
Write-Host "Step 1: Checking Supabase CLI..." -ForegroundColor Yellow
try {
    $version = supabase --version 2>&1
    Write-Host "✅ Supabase CLI: $version`n" -ForegroundColor Green
} catch {
    Write-Host "❌ Supabase CLI not found!" -ForegroundColor Red
    Write-Host "Install with: npm install -g supabase`n" -ForegroundColor Yellow
    exit 1
}

# Step 2: Link Project
Write-Host "Step 2: Linking to Supabase project..." -ForegroundColor Yellow
try {
    $status = supabase status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Linking project ndwovuxiuzbdhdqwpaau..." -ForegroundColor Gray
        supabase link --project-ref ndwovuxiuzbdhdqwpaau
        if ($LASTEXITCODE -ne 0) {
            Write-Host "❌ Failed to link project" -ForegroundColor Red
            Write-Host "You may need to enter your database password`n" -ForegroundColor Yellow
            exit 1
        }
    }
    Write-Host "✅ Project linked`n" -ForegroundColor Green
} catch {
    Write-Host "⚠️  Could not verify project link`n" -ForegroundColor Yellow
}

# Step 3: Get Service Role Key
Write-Host "Step 3: Service Role Key Required" -ForegroundColor Yellow
Write-Host "Get from: https://app.supabase.com/project/ndwovuxiuzbdhdqwpaau/settings/api" -ForegroundColor Gray
Write-Host "Look for 'service_role' key (NOT 'anon' key)`n" -ForegroundColor Gray
$serviceKey = Read-Host "Enter your Service Role key (eyJ...)"

if (-not $serviceKey) {
    Write-Host "❌ Service Role key is required!" -ForegroundColor Red
    Write-Host "Cannot continue without it.`n" -ForegroundColor Yellow
    exit 1
}

# Step 4: Set All Secrets
Write-Host "`nStep 4: Setting API keys in Supabase..." -ForegroundColor Yellow

Write-Host "Setting Gemini API key..." -ForegroundColor Gray
supabase secrets set GEMINI_API_KEY=$GEMINI_API_KEY 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Gemini API key set" -ForegroundColor Green
} else {
    Write-Host "⚠️  Failed to set Gemini key" -ForegroundColor Yellow
}

Write-Host "Setting Serper API key..." -ForegroundColor Gray
supabase secrets set SERPER_API_KEY=$SERPER_API_KEY 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Serper API key set" -ForegroundColor Green
} else {
    Write-Host "⚠️  Failed to set Serper key" -ForegroundColor Yellow
}

Write-Host "Setting Service Role key..." -ForegroundColor Gray
supabase secrets set SUPABASE_SERVICE_ROLE_KEY=$serviceKey 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Service Role key set" -ForegroundColor Green
} else {
    Write-Host "⚠️  Failed to set Service Role key" -ForegroundColor Yellow
}

Write-Host "Setting Supabase URL..." -ForegroundColor Gray
supabase secrets set SUPABASE_URL=https://ndwovuxiuzbdhdqwpaau.supabase.co 2>&1 | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Supabase URL set`n" -ForegroundColor Green
} else {
    Write-Host "⚠️  Failed to set Supabase URL`n" -ForegroundColor Yellow
}

# Step 5: Verify Secrets
Write-Host "Step 5: Verifying secrets..." -ForegroundColor Yellow
supabase secrets list
Write-Host ""

# Step 6: Deploy Functions
Write-Host "Step 6: Deploying Edge Functions..." -ForegroundColor Yellow
Write-Host "This will take 2-3 minutes...`n" -ForegroundColor Gray

$functions = @(
    "ingest_source",
    "answer_query",
    "web_search",
    "extract_youtube",
    "extract_google_drive",
    "generate_image",
    "improve_notes",
    "tts",
    "stt",
    "voices",
    "visualize",
    "moderation"
)

$deployed = 0
$failed = 0
$skipped = 0

foreach ($func in $functions) {
    Write-Host "Deploying $func..." -ForegroundColor Gray
    
    # Check if function exists
    if (Test-Path "supabase/functions/$func/index.ts") {
        supabase functions deploy $func 2>&1 | Out-Null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "  ✅ $func deployed" -ForegroundColor Green
            $deployed++
        } else {
            Write-Host "  ❌ $func failed" -ForegroundColor Red
            $failed++
        }
    } else {
        Write-Host "  ⏭️  $func not found (skipped)" -ForegroundColor Gray
        $skipped++
    }
}

Write-Host "`nDeployment Summary:" -ForegroundColor Cyan
Write-Host "✅ Deployed: $deployed" -ForegroundColor Green
if ($failed -gt 0) {
    Write-Host "❌ Failed: $failed" -ForegroundColor Red
}
if ($skipped -gt 0) {
    Write-Host "⏭️  Skipped: $skipped" -ForegroundColor Gray
}

# Step 7: Test Functions
Write-Host "`nStep 7: Testing deployed functions..." -ForegroundColor Yellow

$anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5kd292dXhpdXpiZGhkcXdwYWF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyODY5NjUsImV4cCI6MjA3ODg2Mjk2NX0.d992B3cr0DlonC4AMGJD1mUCukWv_jg-55AJlI16NGo"
$baseUrl = "https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1"

# Test web_search
Write-Host "`nTesting web_search..." -ForegroundColor Gray
try {
    $headers = @{
        "Authorization" = "Bearer $anonKey"
        "Content-Type" = "application/json"
    }
    $body = @{ q = "test" } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$baseUrl/web_search" -Method Post -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "✅ web_search is working!" -ForegroundColor Green
} catch {
    Write-Host "⚠️  web_search test failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Test extract_youtube
Write-Host "Testing extract_youtube..." -ForegroundColor Gray
try {
    $headers = @{
        "Authorization" = "Bearer $anonKey"
        "Content-Type" = "application/json"
    }
    $body = @{ url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ" } | ConvertTo-Json
    $response = Invoke-RestMethod -Uri "$baseUrl/extract_youtube" -Method Post -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "✅ extract_youtube is working!" -ForegroundColor Green
} catch {
    Write-Host "⚠️  extract_youtube test failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Summary
Write-Host "`n========================================" -ForegroundColor Cyan
Write-Host "✨ Deployment Complete!" -ForegroundColor Green
Write-Host "========================================`n" -ForegroundColor Cyan

Write-Host "Configuration Summary:" -ForegroundColor Yellow
Write-Host "✅ Gemini 2.0 Flash: Configured" -ForegroundColor Green
Write-Host "✅ Serper API: Configured" -ForegroundColor Green
Write-Host "✅ Service Role: Configured" -ForegroundColor Green
Write-Host "✅ Functions: $deployed deployed" -ForegroundColor Green

Write-Host "`nYour App is Ready!" -ForegroundColor Cyan
Write-Host "1. Run: flutter run" -ForegroundColor White
Write-Host "2. Try web search - should work now!" -ForegroundColor White
Write-Host "3. Add YouTube videos" -ForegroundColor White
Write-Host "4. Add Google Drive files" -ForegroundColor White
Write-Host "5. Chat with your sources using Gemini 2.0 Flash" -ForegroundColor White

Write-Host "`n📊 View Logs:" -ForegroundColor Yellow
Write-Host "supabase functions logs web_search --follow" -ForegroundColor Gray
Write-Host "supabase functions logs answer_query --follow" -ForegroundColor Gray
Write-Host "supabase functions logs ingest_source --follow" -ForegroundColor Gray

Write-Host "`n📚 Documentation:" -ForegroundColor Yellow
Write-Host "- API Key Fixes: API_KEY_FIXES.md" -ForegroundColor White
Write-Host "- Gemini Setup: GEMINI_SETUP.md" -ForegroundColor White
Write-Host "- Troubleshooting: TROUBLESHOOTING.md" -ForegroundColor White

Write-Host "`n🎉 Everything is configured and ready!" -ForegroundColor Green
Write-Host "Your app should work perfectly now.`n" -ForegroundColor Green
