# NotebookLLM App Startup Script
# This script starts both the backend and Flutter app

Write-Host "🚀 Starting NotebookLLM Application..." -ForegroundColor Green

# Check if backend is already running
$backendProcess = Get-Process node -ErrorAction SilentlyContinue
if ($backendProcess) {
    Write-Host "✅ Backend is already running (PID: $($backendProcess.Id))" -ForegroundColor Green
} else {
    Write-Host "📦 Starting backend server..." -ForegroundColor Yellow
    Start-Process -FilePath "npm" -ArgumentList "run dev" -WorkingDirectory "backend" -NoNewWindow
    Start-Sleep -Seconds 3
    Write-Host "✅ Backend started" -ForegroundColor Green
}

# Start Flutter app
Write-Host "📱 Starting Flutter app..." -ForegroundColor Yellow
Write-Host "Choose platform:" -ForegroundColor Cyan
Write-Host "1. Chrome (Web)" -ForegroundColor Cyan
Write-Host "2. Windows (Desktop)" -ForegroundColor Cyan
Write-Host "3. Android (Emulator)" -ForegroundColor Cyan

$choice = Read-Host "Enter choice (1-3)"

switch ($choice) {
    "1" {
        Write-Host "🌐 Launching Flutter on Chrome..." -ForegroundColor Green
        flutter run -d chrome
    }
    "2" {
        Write-Host "🖥️  Launching Flutter on Windows..." -ForegroundColor Green
        flutter run -d windows
    }
    "3" {
        Write-Host "📱 Launching Flutter on Android..." -ForegroundColor Green
        flutter run -d emulator-5554
    }
    default {
        Write-Host "❌ Invalid choice" -ForegroundColor Red
        exit 1
    }
}

Write-Host "✅ Application started successfully!" -ForegroundColor Green
