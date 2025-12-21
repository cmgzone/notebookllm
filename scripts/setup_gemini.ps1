# Quick Setup Script for Gemini Users
# Run this to set up your Notebook LLM with Gemini

Write-Host "🚀 Notebook LLM - Gemini Setup" -ForegroundColor Cyan
Write-Host "================================`n" -ForegroundColor Cyan

# Step 1: Check CLI
Write-Host "Step 1: Checking Supabase CLI..." -ForegroundColor Yellow
try {
    $version = supabase --version 2>&1
    Write-Host "✅ Supabase CLI installed: $version`n" -ForegroundColor Green
} catch {
    Write-Host "❌ Supabase CLI not found!" -ForegroundColor Red
    Write-Host "Install with: npm install -g supabase`n" -ForegroundColor Yellow
    exit 1
}

# Step 2: Link Project
Write-Host "Step 2: Linking to Supabase project..." -ForegroundColor Yellow
$linked = $false
try {
    $status = supabase status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Project already linked`n" -ForegroundColor Green
        $linked = $true
    }
} catch {}

if (-not $linked) {
    Write-Host "Linking project..." -ForegroundColor Gray
    supabase link --project-ref ndwovuxiuzbdhdqwpaau
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ Project linked successfully`n" -ForegroundColor Green
    } else {
        Write-Host "❌ Failed to link project`n" -ForegroundColor Red
        exit 1
    }
}

# Step 3: Set Secrets
Write-Host "Step 3: Setting up API keys..." -ForegroundColor Yellow
Write-Host "You'll need the following API keys:`n" -ForegroundColor Gray

# Gemini API Key
Write-Host "1. GEMINI_API_KEY (Required for AI)" -ForegroundColor Cyan
Write-Host "   Get from: https://makersuite.google.com/app/apikey" -ForegroundColor Gray
$geminiKey = Read-Host "   Enter your Gemini API key (AIza...)"
if ($geminiKey) {
    supabase secrets set GEMINI_API_KEY=$geminiKey
    Write-Host "   ✅ Gemini API key set`n" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Skipped - AI features won't work`n" -ForegroundColor Yellow
}

# Service Role Key
Write-Host "2. SUPABASE_SERVICE_ROLE_KEY (Required)" -ForegroundColor Cyan
Write-Host "   Get from: https://app.supabase.com/project/ndwovuxiuzbdhdqwpaau/settings/api" -ForegroundColor Gray
$serviceKey = Read-Host "   Enter your Service Role key (eyJ...)"
if ($serviceKey) {
    supabase secrets set SUPABASE_SERVICE_ROLE_KEY=$serviceKey
    Write-Host "   ✅ Service role key set`n" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Skipped - Backend won't work`n" -ForegroundColor Yellow
}

# Serper API Key
Write-Host "3. SERPER_API_KEY (Required for web search)" -ForegroundColor Cyan
Write-Host "   Get from: https://serper.dev/ (free tier available)" -ForegroundColor Gray
$serperKey = Read-Host "   Enter your Serper API key"
if ($serperKey) {
    supabase secrets set SERPER_API_KEY=$serperKey
    Write-Host "   ✅ Serper API key set`n" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Skipped - Web search won't work`n" -ForegroundColor Yellow
}

# Optional Keys
Write-Host "`nOptional API Keys (press Enter to skip):" -ForegroundColor Yellow

# ElevenLabs
Write-Host "`n4. ELEVENLABS_API_KEY (Optional - for audio features)" -ForegroundColor Cyan
Write-Host "   Get from: https://elevenlabs.io/" -ForegroundColor Gray
$elevenLabsKey = Read-Host "   Enter your ElevenLabs API key (or press Enter to skip)"
if ($elevenLabsKey) {
    supabase secrets set ELEVENLABS_API_KEY=$elevenLabsKey
    Write-Host "   ✅ ElevenLabs API key set" -ForegroundColor Green
}

# YouTube
Write-Host "`n5. YOUTUBE_API_KEY (Optional - enhances YouTube features)" -ForegroundColor Cyan
Write-Host "   Get from: https://console.cloud.google.com/" -ForegroundColor Gray
$youtubeKey = Read-Host "   Enter your YouTube API key (or press Enter to skip)"
if ($youtubeKey) {
    supabase secrets set YOUTUBE_API_KEY=$youtubeKey
    Write-Host "   ✅ YouTube API key set" -ForegroundColor Green
}

# Google Drive
Write-Host "`n6. GOOGLE_DRIVE_API_KEY (Optional - for private Drive files)" -ForegroundColor Cyan
Write-Host "   Get from: https://console.cloud.google.com/" -ForegroundColor Gray
$driveKey = Read-Host "   Enter your Google Drive API key (or press Enter to skip)"
if ($driveKey) {
    supabase secrets set GOOGLE_DRIVE_API_KEY=$driveKey
    Write-Host "   ✅ Google Drive API key set" -ForegroundColor Green
}

# Step 4: Deploy Functions
Write-Host "`nStep 4: Deploying Edge Functions..." -ForegroundColor Yellow
Write-Host "This may take a few minutes...`n" -ForegroundColor Gray

$functionsToDeploysupabase = @(
    "ingest_source",
    "answer_query",
    "web_search",
    "extract_youtube",
    "extract_google_drive"
)

foreach ($func in $functionsToDeploy) {
    Write-Host "Deploying $func..." -ForegroundColor Gray
    supabase functions deploy $func
    if ($LASTEXITCODE -eq 0) {
        Write-Host "✅ $func deployed" -ForegroundColor Green
    } else {
        Write-Host "⚠️  $func deployment failed" -ForegroundColor Yellow
    }
}

# Step 5: Verify
Write-Host "`nStep 5: Verifying setup..." -ForegroundColor Yellow

Write-Host "`nDeployed functions:" -ForegroundColor Gray
supabase functions list

Write-Host "`nConfigured secrets:" -ForegroundColor Gray
supabase secrets list

# Summary
Write-Host "`n================================" -ForegroundColor Cyan
Write-Host "✨ Setup Complete!" -ForegroundColor Green
Write-Host "================================`n" -ForegroundColor Cyan

Write-Host "Next Steps:" -ForegroundColor Yellow
Write-Host "1. Run your Flutter app: flutter run" -ForegroundColor White
Write-Host "2. Try adding a YouTube video or Google Drive file" -ForegroundColor White
Write-Host "3. Check function logs if issues occur: supabase functions logs FUNCTION_NAME" -ForegroundColor White

Write-Host "`n📚 Documentation:" -ForegroundColor Yellow
Write-Host "- Gemini Setup: GEMINI_SETUP.md" -ForegroundColor White
Write-Host "- Troubleshooting: TROUBLESHOOTING.md" -ForegroundColor White
Write-Host "- Testing Guide: BACKEND_TESTING_GUIDE.md" -ForegroundColor White

Write-Host "`n🎉 Your Notebook LLM is ready to use with Gemini!" -ForegroundColor Green
