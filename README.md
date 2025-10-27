# ChatBridge - Hardened Production AI Platform

**Bridge Multiple LLM Providers with a Unified Chat Interface**

![ChatBridge UI](docs/ui.png)

A complete, turnkey solution combining LiteLLM's intelligent routing with Open WebUI's beautiful interface - secure, production-ready, designed for small businesses.

## Deployment Options

ChatBridge supports three flexible deployment modes:

### 1. **Production with Cloudflare Tunnel** (Recommended)
- ✅ Secure HTTPS via Cloudflare
- ✅ No need to expose ports 80/443
- ✅ Built-in DDoS protection
- ✅ Requires: Cloudflare account (free), domain name

### 2. **Production with Public Domain** (Traditional)
- ✅ Direct SSL via Let's Encrypt
- ✅ Full control over certificates
- ✅ Requires: Domain name, ports 80/443 accessible

### 3. **Local Development** (Testing)
- ✅ No domain or SSL needed
- ✅ Quick setup for testing
- ✅ Access via http://localhost

## Features

### Security
- ✅ SSL/TLS encryption with automatic Let's Encrypt certificates
- ✅ Rate limiting on all endpoints
- ✅ Security headers (HSTS, CSP, XSS protection)
- ✅ Network isolation (frontend/backend separation)
- ✅ Non-root containers with dropped capabilities
- ✅ Read-only root filesystems where applicable
- ✅ Secrets management via environment variables
- ✅ Basic authentication for admin interfaces
- ✅ PostgreSQL with connection limits
- ✅ Redis with password authentication

### High Availability
- ✅ Health checks for all services
- ✅ Automatic service restart on failure
- ✅ Resource limits and reservations
- ✅ Database connection pooling
- ✅ Redis caching for API responses
- ✅ Automated daily backups

### Monitoring & Maintenance
- ✅ Structured JSON logging
- ✅ Traefik access logs
- ✅ Daily automated database backups
- ✅ Backup retention policy (7 days default)
- ✅ Health check endpoints

## Architecture

```
Internet
    ↓
Traefik (Reverse Proxy + SSL)
    ↓
    ├─→ Open WebUI (Port 8080) - ai.your-domain.com
    │   ├─→ PostgreSQL (openwebui DB)
    │   └─→ LiteLLM (API calls)
    │
    └─→ LiteLLM (Port 4000) - admin.your-domain.com
        ├─→ PostgreSQL (litellm DB)
        ├─→ Redis (caching)
        └─→ External LLM APIs
```

## Prerequisites

### Required for All Deployments:
- Linux server (Ubuntu 20.04+ recommended) or macOS for local dev
- Docker 20.10+
- Docker Compose 2.0+
- 4GB+ RAM (8GB+ recommended)
- 20GB+ disk space

### Additional Requirements by Deployment Type:

**Cloudflare Tunnel:**
- Cloudflare account (free tier works)
- Domain name managed in Cloudflare
- Only SSH port needs to be accessible

**Public Domain:**
- Domain name with DNS control
- Ports 80 and 443 accessible

**Local Development:**
- No additional requirements

## Quick Start

### 1. One-Command Installation

```bash
# Download latest release and run installer
curl -fsSL https://raw.githubusercontent.com/RobertKozak/ChatBridge/main/bootstrap.sh | bash

# Or specify a custom installation directory
INSTALL_DIR=~/my-chatbridge curl -fsSL https://raw.githubusercontent.com/RobertKozak/ChatBridge/main/bootstrap.sh | bash
```

This will:
- Download the latest release package
- Extract to the appropriate directory (macOS: `~/chatbridge`, Linux: `/opt/chatbridge` or `~/chatbridge`)
- Verify all files are present
- Run the installation wizard
- Let you choose deployment type (Cloudflare, Public, or Local)

### 2. Manual Installation

```bash
# Option A: Use bootstrap script
curl -fsSL https://raw.githubusercontent.com/RobertKozak/ChatBridge/main/bootstrap.sh -o bootstrap.sh
chmod +x bootstrap.sh
./bootstrap.sh

# Option B: Download specific version manually
# Visit https://github.com/RobertKozak/ChatBridge/releases/latest
# Download the .tar.gz file, then:
tar -xzf chatbridge-v*.tar.gz
cd chatbridge
./install.sh
```

The bootstrap script will:
1. Auto-detect your OS and use the appropriate installation directory:
   - **macOS**: `~/chatbridge`
   - **Linux**: `/opt/chatbridge` (if writable) or `~/chatbridge`
   - **Custom**: Set `INSTALL_DIR` environment variable to override

The installer will then:
1. Check prerequisites
2. Ask you to choose deployment type:
   - **Cloudflare Tunnel**: Secure cloud deployment with no port exposure
   - **Public Domain**: Traditional deployment with Let's Encrypt SSL
   - **Local Development**: Quick localhost setup for testing
3. Prompt for configuration based on deployment type
4. Generate secure passwords
5. Create directory structure
6. Configure services
7. Start all containers
8. Display access credentials and next steps

## Configuration

### Environment Variables

All configuration is in the `.env` file. Key variables:

```bash
# Domain
DOMAIN=your-domain.com

# API Keys
OPENAI_API_KEY=sk-...
ANTHROPIC_API_KEY=sk-ant-...

# Security
LITELLM_MASTER_KEY=sk-...  # For API access
ENABLE_SIGNUP=false        # Disable public registration

# Models
MODEL_FILTER_LIST=gpt-4,gpt-3.5-turbo,claude-3-opus
```

### DNS Configuration

**For Cloudflare Tunnel:**
- DNS is automatically configured through Cloudflare Dashboard
- No need to point domains to your server IP
- The installer will guide you through the setup

**For Public Domain:**
Point these domains to your server's IP:
- `ai.your-domain.com` → Open WebUI
- `admin.your-domain.com` → LiteLLM Admin UI
- `traefik.your-domain.com` → Traefik Dashboard

**For Local Development:**
- No DNS configuration needed
- Access via localhost

## Usage

### Accessing Services

**Production (Cloudflare or Public Domain):**
- **Open WebUI**: https://ai.your-domain.com
- **LiteLLM API**: https://admin.your-domain.com/v1
- **LiteLLM Admin UI**: https://admin.your-domain.com/ui
- **Traefik Dashboard**: https://traefik.your-domain.com

**Local Development:**
- **Open WebUI**: http://localhost:8080
- **LiteLLM API**: http://localhost:4000/v1
- **LiteLLM Admin UI**: http://localhost:4000/ui
- **Traefik Dashboard**: http://localhost:8081

### API Usage

```bash
# Using LiteLLM API
curl https://admin.your-domain.com/v1/chat/completions \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer YOUR_LITELLM_MASTER_KEY" \
  -d '{
    "model": "gpt-3.5-turbo",
    "messages": [{"role": "user", "content": "Hello!"}]
  }'
```

### Creating Admin User

1. Visit https://ai.your-domain.com
2. Click "Sign Up"
3. First user becomes admin automatically
4. Set ENABLE_SIGNUP=false in .env to disable further signups

## Management

### Docker Compose Commands

```bash
# View all services
docker-compose ps

# View logs
docker-compose logs -f

# View specific service logs
docker-compose logs -f open-webui
docker-compose logs -f litellm

# Restart services
docker-compose restart

# Stop services
docker-compose down

# Update services
docker-compose pull
docker-compose up -d

# Remove everything (including data)
docker-compose down -v
```

### Service Management

```bash
# Restart a specific service
docker-compose restart litellm

# Scale LiteLLM (if needed)
docker-compose up -d --scale litellm=2

# View resource usage
docker stats

# Execute command in container
docker-compose exec postgres psql -U postgres
```

### Backups

#### Automatic Backups
- Run daily at midnight
- Stored in `./backups/` directory
- Retention: 7 days (configurable)

#### Manual Backup
```bash
docker-compose exec backup /backup-script.sh
```

#### Restore from Backup
```bash
# Stop services
docker-compose down

# Restore database
gunzip < backups/litellm_YYYYMMDD_HHMMSS.sql.gz | \
  docker-compose exec -T postgres psql -U postgres -d litellm

# Restart services
docker-compose up -d
```

### Monitoring

```bash
# Check service health
docker-compose ps

# View resource usage
docker stats

# Check disk space
df -h

# View recent logs
docker-compose logs --tail=100 -f

# Check Traefik access logs
docker-compose logs traefik | grep "\"POST"
```

## Security Best Practices

### 1. Firewall Configuration

**For Cloudflare Tunnel:**
```bash
# Enable firewall
sudo ufw enable

# Allow only SSH (Cloudflare Tunnel handles all other traffic)
sudo ufw allow 22/tcp

# Deny all other ports
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

**For Public Domain:**
```bash
# Enable firewall
sudo ufw enable

# Allow SSH, HTTP, HTTPS
sudo ufw allow 22/tcp
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Deny all other ports
sudo ufw default deny incoming
sudo ufw default allow outgoing
```

**For Local Development:**
```bash
# No special firewall configuration needed
# Keep your system firewall enabled
```

### 2. SSL Certificates

- Automatic via Let's Encrypt
- Renews automatically
- Check status: `docker-compose logs traefik`

### 3. Password Management

- All passwords generated automatically
- Stored in `.env` file
- Never commit `.env` to version control
- Use a password manager to store credentials

### 4. API Key Rotation

```bash
# Generate new master key
openssl rand -hex 24 | xargs -I {} echo "sk-{}"

# Update .env file
nano .env  # Update LITELLM_MASTER_KEY

# Restart LiteLLM
docker-compose restart litellm
```

### 5. Regular Updates

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Update Docker images
docker-compose pull
docker-compose up -d

# Restart if needed
docker-compose restart
```

## Troubleshooting

### Services Won't Start

```bash
# Check logs
docker-compose logs

# Check disk space
df -h

# Check Docker daemon
sudo systemctl status docker

# Restart Docker
sudo systemctl restart docker
```

### SSL Certificate Issues

```bash
# Check Traefik logs
docker-compose logs traefik

# Verify DNS propagation
dig your-domain.com
dig litellm.your-domain.com

# Force certificate renewal
docker-compose exec traefik rm /acme/acme.json
docker-compose restart traefik
```

### Database Connection Issues

```bash
# Check database status
docker-compose exec postgres pg_isready

# Check connections
docker-compose exec postgres psql -U postgres -c "SELECT count(*) FROM pg_stat_activity;"

# Restart database
docker-compose restart postgres
```

### Performance Issues

```bash
# Check resource usage
docker stats

# Increase resources in docker-compose.yml
# Restart services
docker-compose up -d
```

## Maintenance

### Daily Tasks
- ✅ Automated backups run automatically

### Weekly Tasks
- Check logs for errors: `docker-compose logs --tail=1000 | grep -i error`
- Review disk space: `df -h`
- Check backup integrity: `ls -lh backups/`

### Monthly Tasks
- Update Docker images: `docker-compose pull && docker-compose up -d`
- Review and rotate logs
- Test restore from backup
- Review user activity in Open WebUI

## Scaling Considerations

### Horizontal Scaling

```bash
# Scale LiteLLM instances
docker-compose up -d --scale litellm=3

# Add load balancer for Open WebUI
# (Requires additional configuration)
```

### Vertical Scaling

Edit `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 8G
```

## Uninstallation

```bash
# Stop and remove all services
docker-compose down

# Remove all data (WARNING: irreversible)
docker-compose down -v
rm -rf postgres_data redis_data open-webui_data

# Remove configuration
rm -rf traefik litellm .env backups
```

## Support

### Common Issues
- Check logs first: `docker-compose logs`
- Review health status: `docker-compose ps`
- Verify DNS configuration
- Ensure ports 80/443 are accessible

### Resources
- LiteLLM Documentation: https://docs.litellm.ai
- Open WebUI Documentation: https://docs.openwebui.com
- Traefik Documentation: https://doc.traefik.io/traefik/

## License

This setup configuration is provided as-is for production use.

## Security Disclosure

If you discover a security vulnerability, please open an issue on GitHub: https://github.com/RobertKozak/ChatBridge/issues

---

**Made with ❤️ for small businesses needing secure AI infrastructure**
