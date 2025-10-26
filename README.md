# ChatBridge - Hardened Production AI Platform

**Bridge Multiple LLM Providers with a Unified Chat Interface**

A complete, turnkey solution combining LiteLLM's intelligent routing with Open WebUI's beautiful interface - secure, production-ready, designed for small businesses.

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

- Linux server (Ubuntu 20.04+ recommended)
- Docker 20.10+
- Docker Compose 2.0+
- 4GB+ RAM (8GB+ recommended)
- 20GB+ disk space
- Domain name with DNS configured
- Ports 80 and 443 accessible

## Quick Start

### 1. One-Command Installation

```bash
# Download and run the setup script
curl -fsSL https://your-repo/setup.sh | bash
```

### 2. Manual Installation

```bash
# Clone or download all files to a directory
cd /opt/ai-platform

# Make setup script executable
chmod +x setup.sh

# Run the setup script
./setup.sh
```

The script will:
1. Check prerequisites
2. Prompt for configuration (domain, email, API keys)
3. Generate secure passwords
4. Create directory structure
5. Configure services
6. Start all containers
7. Display access credentials

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

Point these domains to your server's IP:
- `ai.your-domain.com` → Open WebUI
- `admin.your-domain.com` → LiteLLM API
- `traefik.your-domain.com` → Traefik Dashboard

## Usage

### Accessing Services

- **Open WebUI**: https://ai.your-domain.com
- **LiteLLM API**: https://admin.your-domain.com/v1
- **Traefik Dashboard**: https://traefik.your-domain.com

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

If you discover a security vulnerability, please email security@your-domain.com

---

**Made with ❤️ for small businesses needing secure AI infrastructure**
