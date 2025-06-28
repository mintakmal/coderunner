#!/bin/bash

# Production deployment script
echo "🚀 Deploying CodeRunner to production..."

# Stop existing services
echo "🛑 Stopping existing services..."
docker-compose down

# Pull latest changes
echo "📥 Pulling latest changes..."
git pull origin main

# Build language runners
echo "🏗️  Building language runners..."
chmod +x scripts/build-runners.sh
./scripts/build-runners.sh

# Build and start services
echo "🔄 Building and starting services..."
docker-compose up -d --build

# Check service status
echo "📊 Checking service status..."
docker-compose ps

# Show logs
echo "📋 Recent logs:"
docker-compose logs --tail=20

echo "✅ Deployment complete!"
echo "🌐 Backend should be running on port 3001"
echo "📊 Check status: curl http://localhost:3001/health"