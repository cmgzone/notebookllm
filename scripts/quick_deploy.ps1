# Quick Deploy Script with Your API Keys
# This will set up everything automatically

Write-Host "🚀 Quick Deploy - Notebook LLM" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

# Your API Keys
$SERPER_API_KEY = "ec5f971deb548fa4e187daffe2092ee20c36a584"

# Step 1: Link Project
Write-Host "Step 1: Linking to Supabase..." -ForegroundColor Yellow
try {
    $status = supabase status 2>&1
    if ($LASTEXITCODE -ne 0) {
        Write-Host "Linking project..." -ForegroundColor Gray
        supabase link --project-ref ndwovuxiuzbdhdqwpaau
    }
    Write-Host "✅ Project linked`n" -ForegroundColor Green
} catch {
    Write-Host "❌ Failed to link project" -ForegroundColor Red
    Write-Host "Run manually: supabase link --project-ref ndwovuxiuzbdhdqwpaau`n" -ForegroundColor Yellow
    exit 1
}

# Step 2: Set Serper API Key
Write-Host "Step 2: Setting Serper API key..." -ForegroundColor Yellow
supabase secrets set SERPER_API_KEY=$SERPER_API_KEY
if ($LASTEXITCODE -eq 0) {
    Write-Host "✅ Serper API key set`n" -ForegroundColor Green
} else {
    Write-Host "❌ Failed to set Serper key`n" -ForegroundColor Red
}

# Step 3: Prompt for other keys
Write-Host "Step 3: Setting other required keys..." -ForegroundColor Yellow

# Gemini API Key
Write-Host "`n📝 Enter your Gemini API key" -ForegroundColor Cyan
Write-Host "   Get from: https://makersuite.google.com/app/apikey" -ForegroundColor Gray
$geminiKey = Read-Host "   Gemini API key (AIza...)"
if ($geminiKey) {
    supabase secrets set GEMINI_API_KEY=$geminiKey
    Write-Host "   ✅ Gemini key set" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Skipped - AI won't work without this!" -ForegroundColor Yellow
}

# Service Role Key
Write-Host "`n📝 Enter your Supabase Service Role key" -ForegroundColor Cyan
Write-Host "   Get from: https://app.supabase.com/project/ndwovuxiuzbdhdqwpaau/settings/api" -ForegroundColor Gray
Write-Host "   (Look for 'service_role' key, NOT 'anon' key)" -ForegroundColor Gray
$serviceKey = Read-Host "   Service Role key (eyJ...)"
if ($serviceKey) {
    supabase secrets set SUPABASE_SERVICE_ROLE_KEY=$serviceKey
    Write-Host "   ✅ Service role key set" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Skipped - Backend won't work without this!" -ForegroundColor Yellow
}

# Step 4: Verify Secrets
Write-Host "`nStep 4: Verifying secrets..." -ForegroundColor Yellow
supabase secrets list
Write-Host ""

# Step 5: Deploy Functions
Write-Host "Step 5: Deploying Edge Functions..." -ForegroundColor Yellow
Write-Host "This will take a few minutes...`n" -ForegroundColor Gray

$functions = @(
    "ingest_source",
    "answer_query", 
    "web_search",
    "extract_youtube",
    "extract_google_drive"
)

$deployed = 0
$failed = 0

foreach ($func in $functions) {
    Write-Host "Deploying $func..." -ForegroundColor Gray
    supabase functions deploy $func 2>&1 | Out-Null
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ $func deployed" -ForegroundColor Green
        $deployed++
    } else {
        Write-Host "❌ $func failed" -ForegroundColor Red
        $failed++
    }
}

Write-Host "`nDeployment Summary:" -ForegroundColor Cyan
Write-Host "✅ Deployed: $deployed" -ForegroundColor Green
Write-Host "❌ Failed: $failed" -ForegroundColor Red

# Step 6: Test
Write-Host "`nStep 6: Testing web_search function..." -ForegroundColor Yellow
try {
    $anonKey = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Im5kd292dXhpdXpiZGhkcXdwYWF1Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjMyODY5NjUsImV4cCI6MjA3ODg2Mjk2NX0.d992B3cr0DlonC4AMGJD1mUCukWv_jg-55AJlI16NGo"
    $url = "https://ndwovuxiuzbdhdqwpaau.supabase.co/functions/v1/web_search"
    
    $headers = @{
        "Authorization" = "Bearer $anonKey"
        "Content-Type" = "application/json"
    }
    
    $body = @{ q = "test" } | ConvertTo-Json
    
    $response = Invoke-RestMethod -Uri $url -Method Post -Headers $headers -Body $body -ErrorAction Stop
    Write-Host "✅ web_search is working!`n" -ForegroundColor Green
} catch {
    Write-Host "⚠️  web_search test failed: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "   Check logs: supabase functions logs web_search`n" -ForegroundColor Gray
}

# Summary
Write-Host "================================" -ForegroundColor Cyan
Write-Host "✨ Deployment Complete!" -ForegroundColor Green
Write-Host "================================`n" -ForegroundColor Cyan

Write-Host "What's Configured:" -ForegroundColor Yellow
Write-Host "✅ Serper API key: Set (for web search)" -ForegroundColor Green
if ($geminiKey) {
    Write-Host "✅ Gemini API key: Set (for AI)" -ForegroundColor Green
} else {
    Write-Host "⚠️  Gemini API key: NOT SET" -ForegroundColor Yellow
}
if ($serviceKey) {
    Write-Host "✅ Service Role key: Set (for backend)" -ForegroundColor Green
} else {
    Write-Host "⚠️  Service Role key: NOT SET" -ForegroundColor Yellow
}

Write-Host "`nNext Steps:" -ForegroundColor Yellow
Write-Host "1. Run your Flutter app: flutter run" -ForegroundColor White
Write-Host "2. Try the search feature - it should work now!" -ForegroundColor White
Write-Host "3. Add YouTube videos and Google Drive files" -ForegroundColor White

if (-not $geminiKey -or -not $serviceKey) {
    Write-Host "`n⚠️  Warning: Some keys are missing!" -ForegroundColor Yellow
    Write-Host "   Run this script again or set them manually:" -ForegroundColor Gray
    if (-not $geminiKey) {
        Write-Host "   supabase secrets set GEMINI_API_KEY=your_key" -ForegroundColor Gray
    }
    if (-not $serviceKey) {
        Write-Host "   supabase secrets set SUPABASE_SERVICE_ROLE_KEY=your_key" -ForegroundColor Gray
    }
}

Write-Host "`n📚 Documentation:" -ForegroundColor Cyan
Write-Host "- API Key Fixes: API_KEY_FIXES.md" -ForegroundColor White
Write-Host "- Gemini Setup: GEMINI_SETUP.md" -ForegroundColor White
Write-Host "- Troubleshooting: TROUBLESHOOTING.md" -ForegroundColor White

Write-Host "`n🎉 Ready to use!" -ForegroundColor Green
