# Rebuild Flutter App with GitHub File Viewer Fixes
# This script rebuilds the Flutter app to apply the recent fixes

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "Rebuilding Flutter App" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Clean build artifacts
Write-Host "1. Cleaning build artifacts..." -ForegroundColor Yellow
flutter clean

Write-Host ""
Write-Host "2. Getting dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host ""
Write-Host "3. Building for your platform..." -ForegroundColor Yellow
Write-Host "   (This may take a few minutes)" -ForegroundColor Gray

# Detect platform and build
if ($IsWindows) {
    Write-Host "   Building for Windows..." -ForegroundColor Gray
    flutter build windows --release
} elseif ($IsMacOS) {
    Write-Host "   Building for macOS..." -ForegroundColor Gray
    flutter build macos --release
} elseif ($IsLinux) {
    Write-Host "   Building for Linux..." -ForegroundColor Gray
    flutter build linux --release
} else {
    Write-Host "   Platform detection failed, building for Windows..." -ForegroundColor Gray
    flutter build windows --release
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "Build Complete!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""
Write-Host "The GitHub file viewer fixes have been applied:" -ForegroundColor White
Write-Host "  ✓ Path cleaning (removes leading slashes)" -ForegroundColor Green
Write-Host "  ✓ 30-second timeout on requests" -ForegroundColor Green
Write-Host "  ✓ Better error messages" -ForegroundColor Green
Write-Host "  ✓ Improved loading indicators" -ForegroundColor Green
Write-Host ""
Write-Host "Run the app and try opening GitHub files again!" -ForegroundColor Cyan
