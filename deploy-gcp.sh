#!/bin/bash

# GCP Deployment Script for CodeRunner Backend
# This script deploys the CodeRunner application on GCP Ubuntu 22.04

set -e  # Exit on any error

echo "🚀 Starting CodeRunner GCP Deployment..."
echo "📅 $(date)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ️  $1${NC}"
}

# Check if Docker is available
if ! command -v docker &> /dev/null; then
    print_error "Docker is not installed. Please run the setup script first."
    exit 1
fi

# Check if user is in docker group
if ! groups $USER | grep -q docker; then
    print_error "User is not in docker group. Please log out and log back in."
    exit 1
fi

# Stop existing services
print_info "Stopping existing services..."
docker-compose down 2>/dev/null || true
print_status "Existing services stopped"

# Pull latest changes (if this is an update)
if [ -d ".git" ]; then
    print_info "Pulling latest changes..."
    git pull origin main || git pull origin master || print_warning "Could not pull latest changes"
fi

# Create environment file if it doesn't exist
if [ ! -f "backend/.env" ]; then
    print_info "Creating production environment file..."
    cat > backend/.env <<EOF
NODE_ENV=production
PORT=3001
FRONTEND_URL=http://$(curl -s ifconfig.me):3001
JWT_SECRET=$(openssl rand -base64 32)
EOF
    print_status "Environment file created"
fi

# Install backend dependencies
print_info "Installing backend dependencies..."
cd backend
npm install --only=production
cd ..
print_status "Backend dependencies installed"

# Build language runner images
print_info "Building language runner images..."
chmod +x scripts/build-runners.sh
./scripts/build-runners.sh
print_status "Language runner images built"

# Build and start services
print_info "Building and starting services..."
docker-compose up -d --build
print_status "Services started"

# Wait for services to be ready
print_info "Waiting for services to be ready..."
sleep 10

# Check service status
print_info "Checking service status..."
docker-compose ps

# Test backend health
print_info "Testing backend health..."
for i in {1..30}; do
    if curl -s http://localhost:3001/health > /dev/null; then
        print_status "Backend is healthy!"
        break
    fi
    if [ $i -eq 30 ]; then
        print_error "Backend health check failed after 30 attempts"
        docker-compose logs backend
        exit 1
    fi
    echo "Waiting for backend... ($i/30)"
    sleep 2
done

# Test code execution
print_info "Testing code execution..."
EXECUTION_TEST=$(curl -s -X POST http://localhost:3001/api/execute \
  -H "Content-Type: application/json" \
  -d '{"language":"python","code":"print(\"Hello from GCP!\")"}' | jq -r '.stdout' 2>/dev/null || echo "")

if [ "$EXECUTION_TEST" = "Hello from GCP!" ]; then
    print_status "Code execution test passed!"
else
    print_warning "Code execution test failed. Check logs for details."
fi

# Get external IP
EXTERNAL_IP=$(curl -s ifconfig.me)

# Show deployment summary
echo ""
echo "🎉 Deployment Summary"
echo "===================="
echo "📍 External IP: $EXTERNAL_IP"
echo "🌐 Backend URL: http://$EXTERNAL_IP:3001"
echo "🏥 Health Check: http://$EXTERNAL_IP:3001/health"
echo "📊 API Endpoint: http://$EXTERNAL_IP:3001/api/execute"
echo ""

# Show recent logs
print_info "Recent logs (last 20 lines):"
docker-compose logs --tail=20

echo ""
print_status "Deployment completed successfully!"
print_info "Useful commands:"
echo "• View logs: docker-compose logs -f"
echo "• Check status: docker-compose ps"
echo "• Restart services: docker-compose restart"
echo "• Update deployment: ./scripts/deploy-gcp.sh"
echo "• Monitor system: ~/monitor.sh"
echo ""

# Test API endpoint
print_info "Testing API endpoint..."
echo "curl -X POST http://$EXTERNAL_IP:3001/api/execute \\"
echo "  -H \"Content-Type: application/json\" \\"
echo "  -d '{\"language\":\"python\",\"code\":\"print(\\\"Hello, World!\\\")\"}'"
echo ""

print_warning "Make sure to:"
echo "1. Configure your domain DNS to point to $EXTERNAL_IP"
echo "2. Set up HTTPS with Caddy or Nginx (see documentation)"
echo "3. Configure regular backups"
echo "4. Monitor system resources"