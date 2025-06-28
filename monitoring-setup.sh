#!/bin/bash

# Set up monitoring and alerting for CodeRunner

echo "📊 Setting up monitoring for CodeRunner..."

# Install monitoring tools
sudo apt install -y htop iotop nethogs

# Create monitoring script
cat > ~/monitor-detailed.sh <<'EOF'
#!/bin/bash

echo "📊 CodeRunner Detailed Monitoring - $(date)"
echo "=============================================="

# System Information
echo "🖥️  System Information:"
echo "Hostname: $(hostname)"
echo "Uptime: $(uptime -p)"
echo "Load Average: $(uptime | awk -F'load average:' '{print $2}')"
echo "Users: $(who | wc -l) logged in"

echo ""
echo "💾 Memory Usage:"
free -h

echo ""
echo "💿 Disk Usage:"
df -h

echo ""
echo "🔥 CPU Usage (top 5 processes):"
ps aux --sort=-%cpu | head -6

echo ""
echo "🐳 Docker Status:"
echo "Running containers: $(docker ps -q | wc -l)"
echo "Total containers: $(docker ps -aq | wc -l)"
echo "Images: $(docker images -q | wc -l)"

echo ""
echo "📊 Docker Stats:"
docker stats --no-stream --format "table {{.Container}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}"

echo ""
echo "🌐 Network Connections:"
echo "Active connections on port 3001: $(ss -tuln | grep :3001 | wc -l)"
echo "Total TCP connections: $(ss -t | wc -l)"

echo ""
echo "📋 Service Status:"
systemctl is-active docker
systemctl is-active ufw
if systemctl is-active caddy &>/dev/null; then
    echo "caddy: $(systemctl is-active caddy)"
fi

echo ""
echo "🔍 Recent Errors (last 10):"
journalctl --since "1 hour ago" -p err --no-pager | tail -10

echo ""
echo "📈 CodeRunner Backend Logs (last 5):"
cd ~/coderunner && docker-compose logs --tail=5 backend
EOF

chmod +x ~/monitor-detailed.sh

# Create log rotation for Docker
sudo tee /etc/logrotate.d/docker-containers <<EOF
/var/lib/docker/containers/*/*.log {
    rotate 7
    daily
    compress
    size=1M
    missingok
    delaycompress
    copytruncate
}
EOF

# Create alerting script
cat > ~/alert.sh <<'EOF'
#!/bin/bash

# Simple alerting script for CodeRunner
# Configure with your notification method

ALERT_EMAIL="your-email@example.com"
HOSTNAME=$(hostname)

# Check disk usage
DISK_USAGE=$(df / | awk 'NR==2 {print $5}' | sed 's/%//')
if [ $DISK_USAGE -gt 80 ]; then
    echo "ALERT: Disk usage is ${DISK_USAGE}% on $HOSTNAME" | mail -s "Disk Alert - $HOSTNAME" $ALERT_EMAIL
fi

# Check memory usage
MEM_USAGE=$(free | grep Mem | awk '{printf("%.0f", $3/$2 * 100.0)}')
if [ $MEM_USAGE -gt 90 ]; then
    echo "ALERT: Memory usage is ${MEM_USAGE}% on $HOSTNAME" | mail -s "Memory Alert - $HOSTNAME" $ALERT_EMAIL
fi

# Check if backend is responding
if ! curl -s http://localhost:3001/health > /dev/null; then
    echo "ALERT: CodeRunner backend is not responding on $HOSTNAME" | mail -s "Service Alert - $HOSTNAME" $ALERT_EMAIL
fi

# Check Docker daemon
if ! systemctl is-active docker > /dev/null; then
    echo "ALERT: Docker daemon is not running on $HOSTNAME" | mail -s "Docker Alert - $HOSTNAME" $ALERT_EMAIL
fi
EOF

chmod +x ~/alert.sh

# Set up cron jobs for monitoring
(crontab -l 2>/dev/null; echo "# CodeRunner monitoring") | crontab -
(crontab -l 2>/dev/null; echo "*/5 * * * * ~/alert.sh") | crontab -
(crontab -l 2>/dev/null; echo "0 */6 * * * ~/monitor-detailed.sh >> ~/monitoring.log") | crontab -
(crontab -l 2>/dev/null; echo "0 2 * * * ~/backup.sh") | crontab -

echo "✅ Monitoring setup completed!"
echo "📊 Run ~/monitor-detailed.sh for detailed monitoring"
echo "🔔 Alerts will be checked every 5 minutes"
echo "📝 Monitoring logs will be saved to ~/monitoring.log"