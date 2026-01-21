# NotebookLLM Backend Deployment Script for Windows
param(
    [Parameter(Mandatory=$false)]
    [ValidateSet("staging", "production")]
    [string]$Environment = "staging"
)

$ErrorActionPreference = "Stop"

$REGISTRY = "ghcr.io"
$IMAGE_NAME = "cmgzone/notebookllm/backend"

Write-Host "🚀 Deploying NotebookLLM Backend to $Environment" -ForegroundColor Green

# Check if required tools are installed
try {
    docker --version | Out-Null
} catch {
    Write-Host "❌ Docker is required but not installed." -ForegroundColor Red
    exit 1
}

try {
    docker-compose --version | Out-Null
} catch {
    Write-Host "❌ Docker Compose is required but not installed." -ForegroundColor Red
    exit 1
}

# Load environment variables
$envFile = ".env.$Environment"
if (Test-Path $envFile) {
    Write-Host "📋 Loading environment variables from $envFile" -ForegroundColor Yellow
    Get-Content $envFile | ForEach-Object {
        if ($_ -match "^([^#][^=]+)=(.*)$") {
            [Environment]::SetEnvironmentVariable($matches[1], $matches[2], "Process")
        }
    }
} else {
    Write-Host "⚠️  No $envFile file found, using default values" -ForegroundColor Yellow
}

# Build and push Docker image
Write-Host "🔨 Building Docker image..." -ForegroundColor Blue
docker build -t "$REGISTRY/$IMAGE_NAME`:$Environment" ../

Write-Host "📤 Pushing Docker image..." -ForegroundColor Blue
docker push "$REGISTRY/$IMAGE_NAME`:$Environment"

# Deploy using docker-compose
Write-Host "🚀 Deploying with Docker Compose..." -ForegroundColor Blue
$composeFile = "docker-compose.yml"
$envComposeFile = "docker-compose.$Environment.yml"
if (Test-Path $envComposeFile) {
    $composeFile = $envComposeFile
}

docker-compose -f $composeFile up -d

# Run database migrations
Write-Host "🗄️  Running database migrations..." -ForegroundColor Blue
docker-compose -f $composeFile exec backend npm run migrate

# Health check
Write-Host "🏥 Performing health check..." -ForegroundColor Blue
Start-Sleep -Seconds 10
$port = if ($env:PORT) { $env:PORT } else { "3000" }
$healthUrl = "http://localhost:$port/health"

try {
    $response = Invoke-WebRequest -Uri $healthUrl -UseBasicParsing
    if ($response.StatusCode -eq 200) {
        Write-Host "✅ Deployment successful! Backend is healthy." -ForegroundColor Green
    } else {
        throw "Health check returned status code: $($response.StatusCode)"
    }
} catch {
    Write-Host "❌ Health check failed. Check logs with: docker-compose logs backend" -ForegroundColor Red
    exit 1
}

Write-Host "🎉 Deployment to $Environment completed successfully!" -ForegroundColor Green