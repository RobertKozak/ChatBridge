# ChatBridge - Quick Start Guide

**Bridge Your Way to AI - Fast and Secure**

## Installation in 3 Steps

### Step 1: Prepare Your Server

**System Requirements:**
- Ubuntu 20.04+ (or similar Linux distribution)
- 4GB RAM minimum (8GB recommended)
- 20GB free disk space
- Domain name pointed to your server IP
- Ports 80 and 443 open

**Install Docker:**
```bash
# Ubuntu/Debian
curl -fsSL https://get.docker.com | sh
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
sudo chmod +x /usr/local/bin/docker-compose
```

### Step 2: Run the Setup Script

```bash
# Create installation directory
sudo mkdir -p /opt/ai-platform
cd /opt/ai-platform

# Copy all files to this directory
# (docker-compose.yml, setup.sh, etc.)

# Make scripts executable
chmod +x setup.sh health-check.sh manage.sh backup-script.sh

# Run the automated setup
./setup.sh
```

The setup script will ask you for:
1. **Domain name** (e.g., example.com)
2. **Email address** (for SSL certificates)
3. **API keys** (OpenAI, Anthropic, etc.)

Then it will automatically:
- Generate secure passwords
- Configure all services
- Start Docker containers
- Provision SSL certificates

### Step 3: Access Your Platform

**Wait 2-5 minutes** for all services to start, then:

1. **Open WebUI**: https://your-domain.com
   - Create your admin account (first user = admin)
   - Start chatting with AI models

2. **LiteLLM Dashboard**: https://litellm.your-domain.com
   - Username: admin
   - Password: (shown after setup)

3. **Traefik Dashboard**: https://traefik.your-domain.com
   - Username: admin
   - Password: (shown after setup)

---

## DNS Configuration

Before running setup, configure your DNS:

```
A Record: your-domain.com        → Your Server IP
A Record: litellm.your-domain.com → Your Server IP
A Record: traefik.your-domain.com → Your Server IP
```

Or use a wildcard:
```
A Record: *.your-domain.com → Your Server IP
```

---

## Post-Installation

### Verify Everything is Working

```bash
# Check service status
docker-compose ps

# Run health check
./health-check.sh

# View logs
docker-compose logs -f
```

### Create Your First User

1. Visit https://your-domain.com
2. Click "Sign Up"
3. Fill in your details
4. You're now the admin!

### Disable Public Registration

After creating your admin account:

```bash
# Edit .env file
nano .env

# Change this line:
ENABLE_SIGNUP=false

# Restart Open WebUI
docker-compose restart open-webui
```

---

## Daily Management

### Use the Management Tool

```bash
./manage.sh
```

This interactive tool provides:
- Start/stop/restart services
- View logs and status
- Create/restore backups
- Update services
- Reset passwords
- And more!

### Common Commands

```bash
# View all services
docker-compose ps

# View logs
docker-compose logs -f open-webui

# Restart a service
docker-compose restart litellm

# Update everything
docker-compose pull && docker-compose up -d

# Create backup
./manage.sh  # Select option 7
```

---

## Troubleshooting

### Services Won't Start

```bash
# Check logs for errors
docker-compose logs

# Verify Docker is running
sudo systemctl status docker

# Check disk space
df -h
```

### SSL Certificate Issues

```bash
# Verify DNS is configured
dig your-domain.com

# Check Traefik logs
docker-compose logs traefik

# Force certificate renewal
./manage.sh  # Select option 13
```

### Can't Access Web Interface

1. **Check DNS**: `dig your-domain.com` should return your server IP
2. **Check Firewall**: Ports 80 and 443 must be open
3. **Check Services**: `docker-compose ps` - all should be "Up"
4. **Check Logs**: `docker-compose logs traefik open-webui`

---

## Security Checklist

After installation:

- [ ] Changed all default passwords
- [ ] Disabled public signup (ENABLE_SIGNUP=false)
- [ ] Configured firewall (allow only 22, 80, 443)
- [ ] Secured .env file (chmod 600 .env)
- [ ] Set up regular backups
- [ ] Configured monitoring
- [ ] Documented admin credentials securely

---

## Getting API Keys

### OpenAI
1. Go to https://platform.openai.com
2. Create account → API Keys → Create new key
3. Copy the key (starts with `sk-`)

### Anthropic
1. Go to https://console.anthropic.com
2. Create account → API Keys → Create key
3. Copy the key (starts with `sk-ant-`)

Add keys to `.env` file:
```bash
OPENAI_API_KEY=sk-your-key-here
ANTHROPIC_API_KEY=sk-ant-your-key-here
```

---

## Next Steps

1. **Configure Models**: Edit `litellm/config.yaml` to add/remove models
2. **Set Up Monitoring**: Use `health-check.sh` in a cron job
3. **Backup Strategy**: Backups run daily, verify in `backups/` folder
4. **User Training**: Share https://your-domain.com with your team
5. **Cost Monitoring**: Check usage in LiteLLM dashboard

---

## Support

- **Check Logs**: `docker-compose logs [service-name]`
- **Run Health Check**: `./health-check.sh`
- **View Documentation**: See README.md
- **Interactive Management**: `./manage.sh`

---

**Your AI platform is ready!** 🚀

Start chatting at: https://your-domain.com
