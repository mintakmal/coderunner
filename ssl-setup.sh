#!/bin/bash

# SSL Setup script for CodeRunner
# Supports both Caddy and Nginx+Certbot

DOMAIN=$1
METHOD=${2:-caddy}  # Default to Caddy

if [ -z "$DOMAIN" ]; then
    echo "Usage: $0 your-domain.com [caddy|nginx]"
    echo "Example: $0 coderunner.example.com caddy"
    exit 1
fi

echo "🔒 Setting up SSL for $DOMAIN using $METHOD"

if [ "$METHOD" = "caddy" ]; then
    # Install Caddy
    echo "📦 Installing Caddy..."
    sudo apt install -y debian-keyring debian-archive-keyring apt-transport-https
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | sudo gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg
    curl -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | sudo tee /etc/apt/sources.list.d/caddy-stable.list
    sudo apt update
    sudo apt install caddy

    # Configure Caddyfile
    echo "⚙️  Configuring Caddy..."
    sudo tee /etc/caddy/Caddyfile > /dev/null <<EOF
$DOMAIN {
    reverse_proxy localhost:3001
    
    encode gzip
    
    header {
        Strict-Transport-Security max-age=31536000;
        X-Content-Type-Options nosniff
        X-Frame-Options DENY
        X-XSS-Protection "1; mode=block"
        Referrer-Policy strict-origin-when-cross-origin
    }
}
EOF

    # Start Caddy
    sudo systemctl enable caddy
    sudo systemctl start caddy
    
elif [ "$METHOD" = "nginx" ]; then
    # Install Nginx and Certbot
    echo "📦 Installing Nginx and Certbot..."
    sudo apt install -y nginx certbot python3-certbot-nginx

    # Configure Nginx
    echo "⚙️  Configuring Nginx..."
    sudo tee /etc/nginx/sites-available/coderunner > /dev/null <<EOF
server {
    listen 80;
    server_name $DOMAIN;

    location / {
        proxy_pass http://localhost:3001;
        proxy_http_version 1.1;
        proxy_set_header Upgrade \$http_upgrade;
        proxy_set_header Connection 'upgrade';
        proxy_set_header Host \$host;
        proxy_set_header X-Real-IP \$remote_addr;
        proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto \$scheme;
        proxy_cache_bypass \$http_upgrade;
        
        # Security headers
        add_header X-Frame-Options DENY;
        add_header X-Content-Type-Options nosniff;
        add_header X-XSS-Protection "1; mode=block";
    }
}
EOF

    # Enable site
    sudo ln -sf /etc/nginx/sites-available/coderunner /etc/nginx/sites-enabled/
    sudo nginx -t
    sudo systemctl restart nginx

    # Get SSL certificate
    echo "🔐 Obtaining SSL certificate..."
    sudo certbot --nginx -d $DOMAIN --non-interactive --agree-tos --email admin@$DOMAIN

    # Set up auto-renewal
    echo "🔄 Setting up auto-renewal..."
    (crontab -l 2>/dev/null; echo "0 12 * * * /usr/bin/certbot renew --quiet") | crontab -
fi

# Update backend environment
echo "⚙️  Updating backend configuration..."
cd ~/coderunner
sed -i "s|FRONTEND_URL=.*|FRONTEND_URL=https://$DOMAIN|" backend/.env
docker-compose restart backend

echo "✅ SSL setup completed!"
echo "🌐 Your site should be available at: https://$DOMAIN"

if [ "$METHOD" = "caddy" ]; then
    echo "📋 Check Caddy status: sudo systemctl status caddy"
    echo "📋 Check Caddy logs: sudo journalctl -u caddy -f"
else
    echo "📋 Check Nginx status: sudo systemctl status nginx"
    echo "📋 Check SSL certificate: sudo certbot certificates"
fi