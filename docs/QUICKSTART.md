# ChatBridge - Quick Start Guide

**Bridge Your Way to AI - Fast and Secure**

## Choose Your Deployment Type

ChatBridge supports three deployment options:

- **🌐 Cloudflare Tunnel**: Secure cloud deployment (recommended)
- **🌍 Public Domain**: Traditional deployment with Let's Encrypt
- **💻 Local Development**: Quick localhost setup for testing

The installer will guide you through the setup based on your choice.

## Installation in 3 Steps

### Step 1: Prepare Your Server

**System Requirements (All Deployments):**
- Ubuntu 20.04+ (or similar Linux distribution) or macOS
- 4GB RAM minimum (8GB recommended)
- 20GB free disk space
- Docker and Docker Compose

**Additional Requirements:**

**For Cloudflare Tunnel:**
- Cloudflare account (free)
- Domain name in Cloudflare
- Only SSH port needs to be open

**For Public Domain:**
- Domain name with DNS access
- Ports 80 and 443 open

**For Local Development:**
- No additional requirements

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

### Step 2: Download and Install ChatBridge

**Option A: One-Command Install (Recommended)**

```bash
curl -fsSL https://raw.githubusercontent.com/RobertKozak/ChatBridge/main/bootstrap.sh | bash
```

**Option B: Manual Install**

```bash
# Download bootstrap script
curl -fsSL https://raw.githubusercontent.com/RobertKozak/ChatBridge/main/bootstrap.sh -o bootstrap.sh

# Make it executable and run
chmod +x bootstrap.sh
./bootstrap.sh
```

The bootstrap script will:
- Download the latest release
- Extract to `/opt/chatbridge`
- Verify all required files
- Start the installation wizard

The installation wizard will:
1. **Ask you to choose a deployment type:**
   - Cloudflare Tunnel (recommended for production)
   - Public Domain (traditional setup)
   - Local Development (testing)

2. **Collect configuration based on your choice:**
   - **Cloudflare**: Domain, Tunnel ID, API keys
   - **Public Domain**: Domain, email, API keys
   - **Local**: Just API keys (optional)

3. **Automatically configure everything:**
   - Generate secure passwords
   - Set up services
   - Start Docker containers
   - Configure SSL (if applicable)

### Step 3: Access Your Platform

**Wait 2-5 minutes** for all services to start, then:

**For Production Deployments (Cloudflare or Public Domain):**

1. **Open WebUI**: https://ai.your-domain.com
   - Create your admin account (first user = admin)
   - Start chatting with AI models

2. **LiteLLM Admin UI**: https://admin.your-domain.com/ui
   - Username: admin
   - Password: (shown after setup)

3. **Traefik Dashboard**: https://traefik.your-domain.com
   - Username: admin
   - Password: (shown after setup)

**For Local Development:**

1. **Open WebUI**: http://localhost:8080
   - Create your admin account
   - Start chatting

2. **LiteLLM Admin UI**: http://localhost:4000/ui
   - Username: admin
   - Password: (shown after setup)

3. **Traefik Dashboard**: http://localhost:8081
   - Username: admin
   - Password: (shown after setup)

---

## DNS Configuration

### For Cloudflare Tunnel:
DNS is configured automatically via the Cloudflare Dashboard. The installer will guide you through:
1. Creating the tunnel
2. Adding DNS routes
3. Verifying configuration

### For Public Domain:
Before running setup, configure your DNS:

```
A Record: ai.your-domain.com     → Your Server IP
A Record: admin.your-domain.com  → Your Server IP
A Record: traefik.your-domain.com → Your Server IP
```

Or use a wildcard:
```
A Record: *.your-domain.com → Your Server IP
```

### For Local Development:
No DNS configuration needed!

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

1. Visit https://ai.your-domain.com
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

- [ ] Changed all default passwords (if needed)
- [ ] Disabled public signup (ENABLE_SIGNUP=false)
- [ ] Configured firewall:
  - **Cloudflare**: Allow only port 22 (SSH)
  - **Public Domain**: Allow ports 22, 80, 443
  - **Local**: Use system firewall
- [ ] Secured .env file (chmod 600 .env)
- [ ] Set up regular backups
- [ ] Configured monitoring
- [ ] Documented admin credentials securely

## Deployment-Specific Tips

### Cloudflare Tunnel
- ✅ No need to open ports 80/443
- ✅ Built-in DDoS protection
- ✅ SSL automatically provided
- ✅ Can access via Cloudflare's network
- ⚠️ Verify tunnel is running: `cloudflared tunnel list`

### Public Domain
- ✅ Full control over SSL certificates
- ✅ Direct connection to your server
- ⚠️ Ensure ports 80/443 are accessible
- ⚠️ Monitor Let's Encrypt certificate renewal

### Local Development
- ✅ No SSL/domain setup needed
- ✅ Quick for testing and development
- ⚠️ **Not for production use**
- ⚠️ No HTTPS (HTTP only)

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

1. **Configure Models**: Add/remove models via the LiteLLM Admin UI at https://admin.your-domain.com/ui
2. **Set Up Monitoring**: Use `health-check.sh` in a cron job
3. **Backup Strategy**: Backups run daily, verify in `backups/` folder
4. **User Training**: Share https://ai.your-domain.com with your team
5. **Cost Monitoring**: Check usage in LiteLLM dashboard

---

## Support

- **Check Logs**: `docker-compose logs [service-name]`
- **Run Health Check**: `./health-check.sh`
- **View Documentation**: See README.md
- **Interactive Management**: `./manage.sh`

---

**Your AI platform is ready!** 🚀

Start chatting at: https://ai.your-domain.com
