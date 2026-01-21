#!/bin/bash

# NotebookLLM Backend Deployment Script
set -e

ENVIRONMENT=${1:-staging}
REGISTRY="ghcr.io"
IMAGE_NAME="cmgzone/notebookllm/backend"

echo "🚀 Deploying NotebookLLM Backend to $ENVIRONMENT"

# Validate environment
if [[ "$ENVIRONMENT" != "staging" && "$ENVIRONMENT" != "production" ]]; then
    echo "❌ Invalid environment. Use 'staging' or 'production'"
    exit 1
fi

# Check if required tools are installed
command -v docker >/dev/null 2>&1 || { echo "❌ Docker is required but not installed."; exit 1; }
command -v docker-compose >/dev/null 2>&1 || { echo "❌ Docker Compose is required but not installed."; exit 1; }

# Load environment variables
if [ -f ".env.$ENVIRONMENT" ]; then
    echo "📋 Loading environment variables from .env.$ENVIRONMENT"
    export $(cat .env.$ENVIRONMENT | grep -v '^#' | xargs)
else
    echo "⚠️  No .env.$ENVIRONMENT file found, using default values"
fi

# Build and push Docker image
echo "🔨 Building Docker image..."
docker build -t $REGISTRY/$IMAGE_NAME:$ENVIRONMENT ../

echo "📤 Pushing Docker image..."
docker push $REGISTRY/$IMAGE_NAME:$ENVIRONMENT

# Deploy using docker-compose
echo "🚀 Deploying with Docker Compose..."
COMPOSE_FILE="docker-compose.yml"
if [ -f "docker-compose.$ENVIRONMENT.yml" ]; then
    COMPOSE_FILE="docker-compose.$ENVIRONMENT.yml"
fi

docker-compose -f $COMPOSE_FILE up -d

# Run database migrations
echo "🗄️  Running database migrations..."
docker-compose -f $COMPOSE_FILE exec backend npm run migrate

# Health check
echo "🏥 Performing health check..."
sleep 10
HEALTH_URL="http://localhost:${PORT:-3000}/health"
if curl -f $HEALTH_URL > /dev/null 2>&1; then
    echo "✅ Deployment successful! Backend is healthy."
else
    echo "❌ Health check failed. Check logs with: docker-compose logs backend"
    exit 1
fi

echo "🎉 Deployment to $ENVIRONMENT completed successfully!"