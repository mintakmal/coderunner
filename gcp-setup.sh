#!/bin/bash

# GCP Ubuntu 22.04 Setup Script for CodeRunner Backend
# This script automates the initial setup of a GCP Ubuntu 22.04 instance

set -e  # Exit on any error

echo "🚀 Starting CodeRunner GCP Setup..."
echo "📅 $(date)"
echo "🖥️  System: $(lsb_release -d | cut -f2)"

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

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "This script should not be run as root. Please run as a regular user with sudo privileges."
   exit 1
fi

# Update system packages
print_info "Updating system packages..."
sudo apt update && sudo apt upgrade -y
print_status "System packages updated"

# Install essential packages
print_info "Installing essential packages..."
sudo apt install -y \
    curl \
    wget \
    git \
    unzip \
    software-properties-common \
    apt-transport-https \
    ca-certificates \
    gnupg \
    lsb-release \
    htop \
    vim \
    ufw \
    fail2ban
print_status "Essential packages installed"

# Install Docker
print_info "Installing Docker..."
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    sudo usermod -aG docker $USER
    rm get-docker.sh
    print_status "Docker installed successfully"
else
    print_warning "Docker is already installed"
fi

# Install Docker Compose
print_info "Installing Docker Compose..."
if ! command -v docker-compose &> /dev/null; then
    DOCKER_COMPOSE_VERSION=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep 'tag_name' | cut -d\" -f4)
    sudo curl -L "https://github.com/docker/compose/releases/download/${DOCKER_COMPOSE_VERSION}/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    print_status "Docker Compose installed successfully"
else
    print_warning "Docker Compose is already installed"
fi

# Install Node.js 18
print_info "Installing Node.js 18..."
if ! command -v node &> /dev/null; then
    curl -fsSL https://deb.nodesource.com/setup_18.x | sudo -E bash -
    sudo apt-get install -y nodejs
    print_status "Node.js installed successfully"
else
    print_warning "Node.js is already installed"
fi

# Configure UFW firewall
print_info "Configuring firewall..."
sudo ufw --force reset
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 3001/tcp comment 'CodeRunner Backend'
sudo ufw allow 80/tcp comment 'HTTP'
sudo ufw allow 443/tcp comment 'HTTPS'
sudo ufw --force enable
print_status "Firewall configured"

# Configure fail2ban
print_info "Configuring fail2ban..."
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[DEFAULT]
bantime = 3600
findtime = 600
maxretry = 3

[sshd]
enabled = true
port = ssh
logpath = /var/log/auth.log
maxretry = 3
EOF

sudo systemctl enable fail2ban
sudo systemctl start fail2ban
print_status "Fail2ban configured"

# Create application directory
print_info "Creating application directory..."
mkdir -p ~/coderunner
cd ~/coderunner
print_status "Application directory created"

# Create swap file (if not exists and system has less than 4GB RAM)
TOTAL_MEM=$(free -m | awk 'NR==2{printf "%.0f", $2}')
if [ $TOTAL_MEM -lt 4096 ] && [ ! -f /swapfile ]; then
    print_info "Creating swap file (system has less than 4GB RAM)..."
    sudo fallocate -l 2G /swapfile
    sudo chmod 600 /swapfile
    sudo mkswap /swapfile
    sudo swapon /swapfile
    echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
    print_status "Swap file created"
fi

# Optimize system settings
print_info "Optimizing system settings..."
# Increase file descriptor limits
echo "* soft nofile 65536" | sudo tee -a /etc/security/limits.conf
echo "* hard nofile 65536" | sudo tee -a /etc/security/limits.conf

# Configure Docker daemon
sudo mkdir -p /etc/docker
sudo tee /etc/docker/daemon.json > /dev/null <<EOF
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "storage-driver": "overlay2"
}
EOF

print_status "System optimization complete"

# Create useful aliases
print_info "Creating useful aliases..."
cat >> ~/.bashrc <<EOF

# CodeRunner aliases
alias cr-logs='docker-compose logs -f'
alias cr-status='docker-compose ps'
alias cr-restart='docker-compose restart'
alias cr-update='git pull && docker-compose up -d --build'
alias cr-backup='~/backup.sh'
EOF

print_status "Aliases created"

# Create backup script
print_info "Creating backup script..."
cat > ~/backup.sh <<'EOF'
#!/bin/bash
DATE=$(date +%Y%m%d_%H%M%S)
BACKUP_DIR="/home/$USER/backups"
mkdir -p $BACKUP_DIR

echo "🔄 Starting backup at $(date)"

# Backup database
if [ -f ~/coderunner/backend/coderunner.db ]; then
    cp ~/coderunner/backend/coderunner.db $BACKUP_DIR/coderunner_$DATE.db
    echo "✅ Database backed up"
fi

# Backup configuration
tar -czf $BACKUP_DIR/config_$DATE.tar.gz -C ~/coderunner backend/.env docker-compose.yml 2>/dev/null || true

# Keep only last 7 days of backups
find $BACKUP_DIR -name "*.db" -mtime +7 -delete 2>/dev/null || true
find $BACKUP_DIR -name "*.tar.gz" -mtime +7 -delete 2>/dev/null || true

echo "✅ Backup completed at $(date)"
EOF

chmod +x ~/backup.sh
print_status "Backup script created"

# Create update script
print_info "Creating update script..."
cat > ~/update.sh <<'EOF'
#!/bin/bash
echo "🔄 Starting system update at $(date)"

# Update system packages
sudo apt update && sudo apt upgrade -y

# Update Docker images
cd ~/coderunner
docker-compose pull

# Rebuild and restart services
docker-compose up -d --build

# Clean up unused Docker resources
docker system prune -f

echo "✅ Update completed at $(date)"
EOF

chmod +x ~/update.sh
print_status "Update script created"

# Create monitoring script
print_info "Creating monitoring script..."
cat > ~/monitor.sh <<'EOF'
#!/bin/bash
echo "📊 CodeRunner System Status - $(date)"
echo "=================================="

echo "🖥️  System Resources:"
echo "CPU Usage: $(top -bn1 | grep "Cpu(s)" | awk '{print $2}' | cut -d'%' -f1)%"
echo "Memory Usage: $(free | grep Mem | awk '{printf("%.1f%%", $3/$2 * 100.0)}')"
echo "Disk Usage: $(df -h / | awk 'NR==2 {print $5}')"

echo ""
echo "🐳 Docker Status:"
docker-compose ps

echo ""
echo "📋 Recent Logs (last 10 lines):"
docker-compose logs --tail=10

echo ""
echo "🔥 Firewall Status:"
sudo ufw status

echo ""
echo "🌐 Network Connections:"
ss -tuln | grep :3001
EOF

chmod +x ~/monitor.sh
print_status "Monitoring script created"

print_status "GCP setup completed successfully!"
print_info "Next steps:"
echo "1. Log out and log back in to apply Docker group membership"
echo "2. Clone your repository: git clone <your-repo-url> ."
echo "3. Run the deployment script: ./scripts/deploy-gcp.sh"
echo ""
print_info "Useful commands:"
echo "• Monitor system: ~/monitor.sh"
echo "• Update system: ~/update.sh"
echo "• Backup data: ~/backup.sh"
echo "• View logs: cr-logs"
echo "• Check status: cr-status"
echo ""
print_warning "Please log out and log back in before proceeding!"