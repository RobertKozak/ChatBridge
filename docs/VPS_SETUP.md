# ChatBridge VPS Deployment Guide

**Complete guide for deploying ChatBridge on a VPS**

This guide covers all three deployment options:
- **Cloudflare Tunnel** (Recommended - most secure)
- **Public Domain** (Traditional with Let's Encrypt)
- **Local Development** (Testing only)

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [VPS Preparation](#vps-preparation)
3. [Deployment Options](#deployment-options)
4. [Installation](#installation)
5. [Configuration](#configuration)
6. [Deployment](#deployment)
7. [Verification](#verification)
8. [Maintenance](#maintenance)
9. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Required Accounts
- **VPS Provider**: DigitalOcean, Linode, Vultr, AWS, etc.
- **Cloudflare Account**: Free tier is sufficient
- **Domain Name**: Registered and configured in Cloudflare
- **API Keys**:
  - OpenAI API key (https://platform.openai.com)
  - Anthropic API key (https://console.anthropic.com)

### VPS Requirements
- **OS**: Ubuntu 22.04 LTS (recommended) or 20.04+
- **RAM**: 4GB minimum, 8GB recommended
- **Storage**: 20GB minimum, 40GB recommended
- **CPU**: 2 cores minimum
- **Network**: Varies by deployment type (see below)

---

## VPS Preparation

### 1. Initial Server Setup

```bash
# Update system packages
sudo apt update && sudo apt upgrade -y

# Install essential tools
sudo apt install -y curl git vim ufw

# Create a non-root user (if not already done)
sudo adduser chatbridge
sudo usermod -aG sudo chatbridge

# Switch to the new user
su - chatbridge
```

### 2. Configure Firewall

The firewall configuration depends on your deployment choice:

**For Cloudflare Tunnel (Recommended):**
```bash
# Enable firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw enable
sudo ufw status

# Note: We do NOT need to open ports 80/443 - Cloudflare Tunnel handles this
```

**For Public Domain:**
```bash
# Enable firewall
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp
sudo ufw enable
sudo ufw status
```

**For Local Development:**
```bash
# Use default system firewall
# No special ports need to be opened
```

### 3. Install Docker

```bash
# Install Docker
curl -fsSL https://get.docker.com | sh

# Add current user to docker group
sudo usermod -aG docker $USER

# Apply group membership (or logout/login)
newgrp docker

# Verify Docker installation
docker --version
docker compose version
```

### 4. Create Installation Directory

```bash
# Create directory for ChatBridge
sudo mkdir -p /opt/chatbridge
sudo chown $USER:$USER /opt/chatbridge
cd /opt/chatbridge
```

---

## Deployment Options

### Option 1: Cloudflare Tunnel (Recommended)

**Advantages:**
- ✅ No need to expose ports 80/443
- ✅ DDoS protection included
- ✅ SSL automatically provided by Cloudflare
- ✅ Can work behind restrictive firewalls
- ✅ Free tier available

**Requirements:**
- Cloudflare account (free)
- Domain managed in Cloudflare
- cloudflared installed

### Option 2: Public Domain (Traditional)

**Advantages:**
- ✅ Full control over SSL certificates
- ✅ Direct connection to your server
- ✅ No third-party dependencies
- ✅ Let's Encrypt (free) SSL

**Requirements:**
- Domain with DNS control
- Ports 80 and 443 accessible
- Email for Let's Encrypt notifications

### Option 3: Local Development

**Advantages:**
- ✅ No domain needed
- ✅ Quick setup
- ✅ Perfect for testing

**Limitations:**
- ⚠️ No SSL (HTTP only)
- ⚠️ Not suitable for production
- ⚠️ localhost access only

---

## Cloudflare Tunnel Setup (Option 1 Only)

### 1. Add Domain to Cloudflare

1. Log in to [Cloudflare Dashboard](https://dash.cloudflare.com)
2. Click "Add a Site"
3. Enter your domain name (e.g., `avaluate.ai`)
4. Select Free plan
5. Update your domain's nameservers to Cloudflare's nameservers
6. Wait for DNS to propagate (usually 5-30 minutes)

### 2. Create Cloudflare Tunnel

```bash
# Install cloudflared on your VPS
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Authenticate with Cloudflare
cloudflared tunnel login
# This will open a browser - select your domain

# Create a tunnel
cloudflared tunnel create chatbridge

# Note the Tunnel ID from the output (e.g., 7f025965-a6ed-4e28-83df-83a0933818b0)
```

### 3. Configure DNS Routes

```bash
# Add DNS routes for your subdomains
# Replace DOMAIN with your actual domain (e.g., avaluate.ai)
# Replace TUNNEL_ID with your tunnel ID

cloudflared tunnel route dns chatbridge ai.DOMAIN
cloudflared tunnel route dns chatbridge admin.DOMAIN
cloudflared tunnel route dns chatbridge traefik.DOMAIN
```

**Verify DNS routes:**
```bash
cloudflared tunnel route list
```

You should see:
```
ai.DOMAIN       -> TUNNEL_ID
admin.DOMAIN    -> TUNNEL_ID
traefik.DOMAIN  -> TUNNEL_ID
```

### 4. Copy Tunnel Credentials

The tunnel credentials are stored at `~/.cloudflared/TUNNEL_ID.json`. We'll copy this later to the ChatBridge directory.

---

## Installation

### 1. Download ChatBridge

**Option A: Use Bootstrap Script (Recommended)**

```bash
# Download and run bootstrap
curl -fsSL https://raw.githubusercontent.com/RobertKozak/ChatBridge/main/bootstrap.sh | INSTALL_DIR=/opt/chatbridge bash
```

**Option B: Manual Download**

```bash
cd /opt/chatbridge

# Download bootstrap script
curl -fsSL https://raw.githubusercontent.com/RobertKozak/ChatBridge/main/bootstrap.sh -o bootstrap.sh
chmod +x bootstrap.sh

# Set installation directory and run
INSTALL_DIR=/opt/chatbridge ./bootstrap.sh
```

**Option C: From Source (Development)**

```bash
cd /opt/chatbridge
git clone https://github.com/RobertKozak/ChatBridge.git .
```

The bootstrap script automatically downloads the latest stable release package.

> **Note:** The installer will ask you to choose your deployment type (Cloudflare, Public Domain, or Local). Make your choice based on the deployment options section above.

### 2. Cloudflare Tunnel Credentials (Cloudflare Deployment Only)

> **Skip this section if using Public Domain or Local deployment**

The installer will guide you through this, but you can prepare beforehand:

```bash
# Install cloudflared (if not using the installer's guidance)
wget https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-linux-amd64.deb
sudo dpkg -i cloudflared-linux-amd64.deb

# Authenticate and create tunnel
cloudflared tunnel login
cloudflared tunnel create chatbridge

# Note the Tunnel ID - the installer will ask for this
```

The installer will automatically:
- Copy your credentials
- Generate the config.yml
- Set up DNS routes
- Configure ingress rules

---

## Configuration

> **Note:** The installer handles all of this automatically. This section is for reference only.

### The Installer Will Configure:

**For All Deployments:**
- Database passwords
- Redis passwords
- LiteLLM master key
- API keys (OpenAI, Anthropic)

**For Cloudflare Tunnel:**
- Domain name
- Tunnel configuration
- DNS routes

**For Public Domain:**
- Domain name
- Email for SSL certificates

**For Local:**
- No domain or SSL configuration needed

### Manual Configuration (Advanced Users)

Edit `.env` with your actual values:

```bash
# Domain Configuration
DOMAIN=avaluate.ai  # Your actual domain

# Database Configuration
POSTGRES_USER=chatbridge
POSTGRES_PASSWORD=<generate-strong-password>  # Use: openssl rand -base64 32
POSTGRES_DB=chatbridge
LITELLM_DB=litellm
OPENWEBUI_DB=openwebui

# Redis Configuration
REDIS_PASSWORD=<generate-strong-password>  # Use: openssl rand -base64 32

# LiteLLM Configuration
LITELLM_MASTER_KEY=<generate-strong-password>  # Use: openssl rand -base64 32
LITELLM_SALT_KEY=<generate-strong-password>  # Use: openssl rand -base64 32
LITELLM_UI_USERNAME=admin
LITELLM_UI_PASSWORD=<generate-strong-password>  # Use: openssl rand -base64 32

# Open WebUI Configuration
WEBUI_SECRET_KEY=<generate-strong-password>  # Use: openssl rand -base64 32
WEBUI_NAME=AI Assistant
ENABLE_SIGNUP=true  # Set to false after creating admin account
DEFAULT_USER_ROLE=user

# API Keys - Get these from providers
OPENAI_API_KEY=sk-your-openai-key-here
ANTHROPIC_API_KEY=sk-ant-your-anthropic-key-here

# Traefik Configuration
TRAEFIK_BASIC_AUTH=<generate-htpasswd>  # See below
```

### 3. Generate Traefik Basic Auth Password

```bash
# Install htpasswd if needed
sudo apt install -y apache2-utils

# Generate password (replace 'your-password' with actual password)
echo $(htpasswd -nb admin your-password)

# Copy the output to TRAEFIK_BASIC_AUTH in .env
# Example output: admin:$apr1$abc123$xyz789
```

### 4. Secure Environment File

```bash
chmod 600 .env
```

---

## Deployment

### 1. Start Services

```bash
cd /opt/chatbridge/docker

# Pull all images
docker compose pull

# Start all services
docker compose up -d

# Watch logs
docker compose logs -f
```

### 2. Monitor Service Startup

```bash
# Check service status
docker compose ps

# All services should show "Up" and "healthy" after 2-3 minutes
# Watch for:
# - postgres: healthy
# - redis: healthy
# - traefik: healthy
# - litellm: healthy
# - open-webui: Up
# - cloudflared: Up
```

### 3. Verify Cloudflare Tunnel

```bash
# Check cloudflared logs
docker compose logs cloudflared

# You should see:
# - "Connection established" messages
# - "Registered tunnel connection"
# - Multiple connections to Cloudflare edge locations (usually 4)
```

---

## Verification

### 1. Test DNS Resolution

```bash
# Test that DNS is resolving
dig ai.DOMAIN
dig admin.DOMAIN
dig traefik.DOMAIN

# Each should return Cloudflare IPs (104.x.x.x or 172.x.x.x range)
```

### 2. Test HTTPS Access

```bash
# Test Open WebUI (should return 200)
curl -I https://ai.DOMAIN

# Test LiteLLM (should return 308 redirect to /ui)
curl -I https://admin.DOMAIN

# Test Traefik Dashboard (should return 401 - auth required)
curl -I https://traefik.DOMAIN
```

### 3. Browser Testing

Open in your browser:

1. **Open WebUI**: https://ai.DOMAIN
   - Should show signup/login page
   - SSL certificate should be valid (Cloudflare)

2. **LiteLLM Admin**: https://admin.DOMAIN
   - Should redirect to https://admin.DOMAIN/ui
   - Login with credentials from `.env`:
     - Username: `LITELLM_UI_USERNAME`
     - Password: `LITELLM_UI_PASSWORD`

3. **Traefik Dashboard**: https://traefik.DOMAIN
   - Should prompt for basic auth
   - Username: `admin`
   - Password: (the one you used to generate TRAEFIK_BASIC_AUTH)

---

## Post-Deployment

### 1. Create Admin Account

1. Visit https://ai.DOMAIN
2. Click "Sign Up"
3. Create your admin account (first user becomes admin)
4. Log in and verify you can chat

### 2. Disable Public Signup

```bash
# Edit .env
vim /opt/chatbridge/.env

# Change:
ENABLE_SIGNUP=false

# Restart Open WebUI
cd /opt/chatbridge/docker
docker compose restart open-webui
```

### 3. Test AI Integration

1. Log in to Open WebUI
2. Start a new chat
3. Select a model (e.g., GPT-4o or Claude-3.5-Sonnet)
4. Send a test message
5. Verify you get a response

### 4. Configure Additional Models (Optional)

Add/remove models via the LiteLLM Admin UI:

1. Visit https://admin.DOMAIN/ui
2. Navigate to "Models" section
3. Add new models or edit existing ones
4. All changes are stored in the database and persist across restarts

> **Note**: Models are now managed via the database, not config files. The config file only contains infrastructure settings.

---

## Maintenance

### Daily Backups

Backups run automatically daily. Verify:

```bash
# Check backup logs
docker compose logs backup

# List backups
ls -lh /opt/chatbridge/backups/
```

### Update Services

```bash
cd /opt/chatbridge/docker

# Pull latest images
docker compose pull

# Recreate containers with new images
docker compose up -d

# Clean up old images
docker image prune -f
```

### Monitor Resource Usage

```bash
# Check disk usage
df -h

# Check Docker disk usage
docker system df

# View container resource usage
docker stats

# Clean up if needed
docker system prune -a --volumes
```

### View Logs

```bash
# All services
docker compose logs -f

# Specific service
docker compose logs -f litellm
docker compose logs -f open-webui
docker compose logs -f traefik
docker compose logs -f cloudflared

# Last 100 lines
docker compose logs --tail=100 litellm
```

### Restart Services

```bash
# Restart all
docker compose restart

# Restart specific service
docker compose restart litellm
docker compose restart open-webui
```

---

## Troubleshooting

### Services Won't Start

```bash
# Check status
docker compose ps

# View logs for errors
docker compose logs

# Check system resources
free -h
df -h

# Restart Docker daemon
sudo systemctl restart docker
docker compose up -d
```

### Cloudflare Tunnel Not Connecting

```bash
# Check cloudflared logs
docker compose logs cloudflared

# Common issues:
# 1. Incorrect tunnel ID in config.yml
# 2. Missing/incorrect credentials.json
# 3. DNS routes not configured in Cloudflare

# Verify tunnel configuration
cat docker/cloudflared/config.yml

# Test tunnel manually
docker compose exec cloudflared cloudflared tunnel info chatbridge
```

### Sites Not Accessible

```bash
# 1. Verify Cloudflare Tunnel is connected
docker compose logs cloudflared | grep -i "connection\|registered"

# 2. Check Traefik is healthy
docker compose ps traefik
docker compose logs traefik

# 3. Verify DNS in Cloudflare Dashboard
# Go to: Cloudflare Dashboard → Your Domain → DNS → Records
# Ensure CNAME records exist for:
# - ai.DOMAIN → TUNNEL_ID.cfargotunnel.com
# - admin.DOMAIN → TUNNEL_ID.cfargotunnel.com
# - traefik.DOMAIN → TUNNEL_ID.cfargotunnel.com

# 4. Test local connectivity
docker compose exec cloudflared wget -O- http://traefik:80/ping
```

### Database Connection Issues

```bash
# Check PostgreSQL is healthy
docker compose ps postgres

# View PostgreSQL logs
docker compose logs postgres

# Test database connection
docker compose exec postgres psql -U chatbridge -d chatbridge -c "SELECT 1;"

# Reset database (WARNING: destroys data)
docker compose down -v
docker compose up -d
```

### LiteLLM API Errors

```bash
# Check LiteLLM logs
docker compose logs litellm

# Verify API keys in environment
docker compose exec litellm env | grep API_KEY

# Test API key validity
# For OpenAI:
curl https://api.openai.com/v1/models \
  -H "Authorization: Bearer $OPENAI_API_KEY"

# For Anthropic:
curl https://api.anthropic.com/v1/messages \
  -H "x-api-key: $ANTHROPIC_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-3-5-sonnet-20241022","max_tokens":10,"messages":[{"role":"user","content":"Hi"}]}'
```

### High Memory Usage

```bash
# Check container memory usage
docker stats

# Restart memory-heavy containers
docker compose restart litellm open-webui

# If PostgreSQL is using too much memory, adjust settings in docker-compose.yml:
# shared_buffers, effective_cache_size, etc.
```

### Disk Space Issues

```bash
# Check disk usage
df -h

# Check Docker disk usage
docker system df

# Clean up Docker resources
docker system prune -a --volumes  # WARNING: removes unused data

# Clean up old backups (keep last 7 days)
find /opt/chatbridge/backups -name "*.sql" -mtime +7 -delete
```

---

## Security Best Practices

### 1. Regular Updates

```bash
# Update system packages monthly
sudo apt update && sudo apt upgrade -y

# Update Docker images weekly
cd /opt/chatbridge/docker
docker compose pull
docker compose up -d
```

### 2. Monitor Logs

```bash
# Set up log monitoring (optional)
# Install logwatch
sudo apt install -y logwatch

# Or use journalctl
sudo journalctl -u docker -f
```

### 3. Backup Strategy

```bash
# Verify backups are running
ls -lh /opt/chatbridge/backups/

# Test backup restoration periodically
# (on a separate test instance)
```

### 4. API Key Rotation

Rotate API keys every 90 days:

1. Generate new API keys in OpenAI/Anthropic dashboards
2. Update `.env` file
3. Restart services: `docker compose restart litellm`
4. Revoke old API keys

### 5. Password Updates

Update passwords periodically:

```bash
# Generate new passwords
openssl rand -base64 32

# Update .env
vim /opt/chatbridge/.env

# Restart affected services
docker compose restart
```

---

## Performance Optimization

### 1. PostgreSQL Tuning

Already configured in `docker-compose.yml` for 8GB RAM system. Adjust if needed:

```yaml
# For 4GB RAM systems, reduce:
shared_buffers=256MB
effective_cache_size=768MB
```

### 2. Redis Tuning

Already configured with:
- 256MB max memory
- LRU eviction policy
- AOF persistence

### 3. Resource Limits

Monitor and adjust container resource limits in `docker-compose.yml` based on usage.

---

## Monitoring Dashboard

### Set Up Monitoring (Optional)

```bash
# Add Prometheus and Grafana to docker-compose.yml
# (not included by default)

# Or use external monitoring services:
# - Cloudflare Analytics (included free)
# - UptimeRobot (free tier)
# - Better Stack (free tier)
```

### Health Check Script

```bash
# Create a simple health check
cat > /opt/chatbridge/health-check.sh << 'EOF'
#!/bin/bash
echo "=== ChatBridge Health Check ==="
echo ""
echo "Container Status:"
docker compose ps
echo ""
echo "Disk Usage:"
df -h / | tail -1
echo ""
echo "Memory Usage:"
free -h | grep Mem
echo ""
echo "Website Tests:"
curl -sI https://ai.DOMAIN | head -1
curl -sI https://admin.DOMAIN | head -1
curl -sI https://traefik.DOMAIN | head -1
EOF

chmod +x /opt/chatbridge/health-check.sh

# Run it
/opt/chatbridge/health-check.sh
```

---

## Scaling Considerations

### Vertical Scaling

When you need more resources:

1. **Upgrade VPS**: Increase RAM/CPU through your provider
2. **Restart Services**: No configuration changes needed
3. **Verify**: Run health check

### Horizontal Scaling

For high-traffic deployments:

1. **Multiple VPS Instances**: Deploy ChatBridge on multiple servers
2. **Cloudflare Load Balancing**: Use Cloudflare's load balancer (paid feature)
3. **Shared Database**: Use external PostgreSQL database (AWS RDS, etc.)
4. **Redis Cluster**: Use external Redis (AWS ElastiCache, etc.)

---

## Cost Estimates

### Monthly Costs (Approximate)

- **VPS (4GB RAM)**: $20-40/month
- **Domain Name**: $10-15/year
- **Cloudflare**: Free (Tunnel included)
- **OpenAI API**: Pay-per-use (~$0.01-0.10 per request)
- **Anthropic API**: Pay-per-use (~$0.003-0.015 per request)

**Total**: ~$25-50/month + API usage

### Cost Optimization

1. **Use cheaper models**: GPT-4o-mini, Claude-3.5-Haiku for most tasks
2. **Set budget limits**: Configure in LiteLLM dashboard
3. **Monitor usage**: Review costs weekly in provider dashboards
4. **Cache responses**: Already enabled in LiteLLM config
5. **Smaller VPS**: Start with 4GB, upgrade if needed

---

## Support and Resources

### Documentation
- **Quick Start**: See `docs/QUICKSTART.md`
- **Main README**: See `README.md`
- **Docker Compose**: See `docker/docker-compose.yml`
- **LiteLLM API Docs**: https://docs.litellm.ai

### Logs Location
- **Application Logs**: `docker compose logs [service]`
- **Traefik Logs**: `/var/log/traefik/` (inside container)
- **Backup Logs**: `docker compose logs backup`

### Useful Commands
```bash
# View all containers
docker compose ps

# Restart everything
docker compose restart

# Stop everything
docker compose down

# Start everything
docker compose up -d

# Update everything
docker compose pull && docker compose up -d

# View resource usage
docker stats

# Clean up
docker system prune -f
```

---

## Conclusion

You now have ChatBridge running on a VPS with:

- ✅ Secure HTTPS via Cloudflare Tunnel
- ✅ No exposed ports (only SSH)
- ✅ Automatic SSL certificates
- ✅ Multiple AI models (OpenAI + Anthropic)
- ✅ Admin dashboard for monitoring
- ✅ Automatic daily backups
- ✅ Production-ready configuration

**Next Steps:**
1. Create your admin account
2. Disable public signup
3. Test AI chat functionality
4. Share with your team
5. Monitor usage and costs

**Your AI Platform is live!** 🚀

Access at: https://ai.DOMAIN
