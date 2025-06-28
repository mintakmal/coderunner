#!/bin/bash

# GCP Ubuntu 22.04 Setup Script for CodeRunner
echo "🚀 Setting up CodeRunner on GCP Ubuntu 22.04..."

# Update system
echo "📦 Updating system packages..."
sudo apt update && sudo apt upgrade -y

# Install Docker
echo "🐳 Installing Docker..."
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh
sudo usermod -aG docker $USER

# Install Docker Compose
echo "🔧 Installing Docker Compose..."
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose

# Install Node.js
echo "📦 Installing Node.js..."
curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
sudo apt-get install -y nodejs

# Install Git
echo "📦 Installing Git..."
sudo apt install -y git

# Configure firewall
echo "🔥 Configuring firewall..."
sudo ufw allow ssh
sudo ufw allow 3001/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw --force enable

# Create application directory
echo "📁 Creating application directory..."
mkdir -p ~/coderunner
cd ~/coderunner

echo "✅ GCP setup complete!"
echo "📝 Next steps:"
echo "1. Log out and log back in to apply Docker group membership"
echo "2. Clone your repository: git clone <your-repo-url> ."
echo "3. Build and run: chmod +x scripts/build-runners.sh && ./scripts/build-runners.sh"
echo "4. Start the application: docker-compose up -d"