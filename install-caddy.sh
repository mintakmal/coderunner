#!/bin/bash

# Install and configure Caddy for HTTPS
# Usage: ./install-caddy.sh your-domain.com

set -e

DOMAIN=$1

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 your-domain.com"
    exit 1
fi

echo "🔒 Installing Caddy for HTTPS with domain: $DOMAIN"

# Install Caddy
sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
sudo apt update
sudo apt install caddy

# Configure Caddyfile
sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
$DOMAIN {
    reverse_proxy localhost:3001
    
    # Enable compression
    encode gzip
    
    # Security headers
    header {
        # Enable HSTS
        Strict-Transport-Security max-age=31536000;
        # Prevent MIME sniffing
        X-Content-Type-Options nosniff
        # Prevent clickjacking
        X-Frame-Options DENY
        # XSS protection
        X-XSS-Protection "1; mode=block"
        # Referrer policy
        Referrer-Policy strict-origin-when-cross-origin
    }
    
    # Rate limiting
    rate_limit {
        zone static {
            key {remote_host}
            events 100
            window 1m
        }
    }
}
EOF

# Update backend environment
sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=https://$DOMAIN|" ~/coderunner/backend/.env

# Restart services
cd ~/coderunner
docker-compose restart backend

# Start and enable Caddy
sudo systemctl enable caddy
sudo systemctl start caddy

echo "✅ Caddy installed and configured for $DOMAIN"
echo "🌐 Your site should be available at: https://$DOMAIN"
echo "📋 Check Caddy status: sudo systemctl status caddy"
echo "📋 Check Caddy logs: sudo journalctl -u caddy -f"