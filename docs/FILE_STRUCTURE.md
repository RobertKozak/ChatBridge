# ChatBridge - File Structure Documentation

## Overview
This is a complete, production-ready deployment package for ChatBridge - bridging multiple LLM providers (LiteLLM) with a unified chat interface (Open WebUI) with enterprise-grade security hardening.

## File Structure

```
chatbridge/
├── docker-compose.yml          # Main Docker Compose configuration
├── .env.example                # Environment variables template
├── .gitignore                  # Git ignore rules for security
├── README.md                   # Comprehensive documentation
├── QUICKSTART.md               # Quick start guide
│
├── setup.sh                    # Automated installation script ⭐
├── health-check.sh             # Health monitoring script
├── manage.sh                   # Interactive management tool
├── backup-script.sh            # Automated backup script
├── init-db.sql                 # Database initialization
│
├── traefik/                    # Reverse proxy configuration
│   ├── traefik.yml            # Static configuration
│   └── dynamic/               # Dynamic configuration
│       └── security.yml       # Security headers and middleware
│
└── litellm/                    # LiteLLM configuration
    └── config.yaml             # Model and provider settings
```

## Core Files

### docker-compose.yml
Main orchestration file defining all services:
- **Traefik**: Reverse proxy with automatic SSL
- **PostgreSQL**: Database for LiteLLM and Open WebUI
- **Redis**: Caching layer
- **LiteLLM**: LLM proxy and routing
- **Open WebUI**: User interface
- **Backup**: Automated backup service

**Security Features:**
- Network isolation (frontend/backend)
- Non-root containers
- Read-only filesystems
- Capability dropping
- Resource limits
- Health checks

### setup.sh ⭐ MAIN INSTALLATION SCRIPT
**One-command automated setup!**

What it does:
1. Checks prerequisites (Docker, Docker Compose, etc.)
2. Prompts for domain and email
3. Collects API keys
4. Generates secure passwords automatically
5. Creates directory structure
6. Configures all services
7. Starts Docker containers
8. Displays all credentials

**Usage:**
```bash
chmod +x setup.sh
./setup.sh
```

### .env.example
Template for environment variables. The setup script creates a `.env` file with:
- Secure randomly generated passwords
- Your domain configuration
- API keys
- All service credentials

**IMPORTANT:** Never commit `.env` to version control!

## Utility Scripts

### manage.sh
Interactive management tool with menu-driven interface:
- Start/stop/restart services
- View logs and status
- Create/restore backups
- Update services
- Reset passwords
- Cleanup old files
- SSL management
- Export/import config

**Usage:**
```bash
./manage.sh
```

### health-check.sh
Comprehensive health monitoring:
- Service status checks
- URL accessibility tests
- Resource usage monitoring
- Database health
- Redis status
- Backup verification
- SSL certificate status
- Security checks

**Usage:**
```bash
./health-check.sh
```

Can be added to cron for regular monitoring:
```bash
*/15 * * * * /opt/chatbridge/health-check.sh
```

### backup-script.sh
Automated backup script that runs daily:
- Backs up all PostgreSQL databases
- Creates compressed archives
- Manages retention (7 days default)
- Optional S3 upload support
- Verification and logging

**Manual backup:**
```bash
docker-compose exec backup /backup-script.sh
```

## Configuration Files

### traefik/traefik.yml
Traefik static configuration:
- HTTP to HTTPS redirect
- Let's Encrypt automatic SSL
- Dashboard configuration
- Logging settings
- Rate limiting

### traefik/dynamic/security.yml
Security middleware:
- Security headers (HSTS, CSP, XSS protection)
- Frame options
- Content type nosniff
- Referrer policy
- Permissions policy
- Compression
- IP whitelisting options

### litellm/config.yaml
LiteLLM configuration:
- Model definitions (OpenAI, Anthropic, etc.)
- Router settings
- Caching configuration
- Rate limiting
- Fallback strategies
- Content moderation
- Budget controls

### init-db.sql
Database initialization:
- Creates separate databases for LiteLLM and Open WebUI
- Sets up extensions (uuid-ossp, pg_stat_statements)
- Creates audit log tables
- Configures permissions
- Performance tuning

## Directory Structure Created

```
/opt/chatbridge/               # Installation directory
├── backups/                    # Database backups
├── logs/                       # Application logs
├── traefik/
│   ├── acme/                  # SSL certificates (auto-generated)
│   └── dynamic/               # Dynamic configuration
└── litellm/                   # LiteLLM config
```

## Docker Volumes

Persistent data stored in Docker volumes:
- `postgres_data`: PostgreSQL databases
- `redis_data`: Redis cache
- `open-webui_data`: Open WebUI data
- `litellm_tmp`: Temporary files

## Ports

**External (via Traefik):**
- 80: HTTP (redirects to HTTPS)
- 443: HTTPS (all services)

**Internal (Docker network only):**
- 5432: PostgreSQL
- 6379: Redis
- 4000: LiteLLM
- 8080: Open WebUI

## Security Features

### Network Security
- Separate frontend and backend networks
- Backend network is internal (no external access)
- Only Traefik exposes ports to internet

### Container Security
- All containers run as non-root
- Read-only root filesystems
- Capabilities dropped (ALL) and selectively added
- Security options: no-new-privileges
- Resource limits (CPU, memory)

### Data Security
- All passwords auto-generated (32+ characters)
- .env file permissions: 600 (owner read/write only)
- SSL/TLS encryption for all traffic
- Rate limiting on all endpoints
- Security headers on all responses

### Access Control
- Basic auth on Traefik dashboard
- Master key required for LiteLLM API
- User authentication in Open WebUI
- Database password authentication
- Redis password authentication

## Installation Steps

### Quick Installation
```bash
# 1. Copy all files to server
# 2. Run setup script
./setup.sh

# 3. Wait for DNS propagation
# 4. Access your platform
```

### Manual Installation
```bash
# 1. Copy .env.example to .env
cp .env.example .env

# 2. Edit .env with your values
nano .env

# 3. Create directories
mkdir -p traefik/dynamic traefik/acme litellm backups logs

# 4. Set permissions
chmod 600 .env
chmod 600 traefik/acme

# 5. Start services
docker-compose up -d
```

## Monitoring & Maintenance

### Daily
- Automated backups run at midnight
- Check health: `./health-check.sh`

### Weekly
- Review logs: `docker-compose logs --tail=1000 | grep -i error`
- Check disk space: `df -h`
- Verify backups: `ls -lh backups/`

### Monthly
- Update services: `docker-compose pull && docker-compose up -d`
- Test backup restore
- Review user activity
- Check SSL certificate expiry

## Troubleshooting

### Common Issues

**Services won't start:**
```bash
docker-compose logs
docker-compose ps
```

**SSL certificate errors:**
```bash
docker-compose logs traefik
dig your-domain.com
```

**Database connection issues:**
```bash
docker-compose exec postgres pg_isready
docker-compose logs postgres
```

**Out of disk space:**
```bash
df -h
docker system prune -f
```

## Scaling Considerations

### Horizontal Scaling
```bash
# Scale LiteLLM instances
docker-compose up -d --scale litellm=3
```

### Vertical Scaling
Edit resource limits in docker-compose.yml:
```yaml
deploy:
  resources:
    limits:
      cpus: '4'
      memory: 8G
```

## Backup & Recovery

### Backup
- Automatic: Daily at midnight
- Manual: `./manage.sh` → option 7

### Restore
1. Stop services: `docker-compose down`
2. Restore database: `gunzip < backup.sql.gz | docker-compose exec -T postgres psql ...`
3. Start services: `docker-compose up -d`

Or use: `./manage.sh` → option 8

## Updates

### Updating Services
```bash
# Pull latest images
docker-compose pull

# Restart with new images
docker-compose up -d

# Or use management tool
./manage.sh  # option 9
```

### Updating Configuration
1. Edit configuration file
2. Restart affected service: `docker-compose restart [service]`

## Production Checklist

Before going live:
- [ ] DNS configured and propagated
- [ ] SSL certificates provisioned
- [ ] All services healthy
- [ ] Admin account created
- [ ] Public signup disabled
- [ ] Firewall configured
- [ ] Backups verified
- [ ] Monitoring set up
- [ ] Documentation reviewed
- [ ] Credentials stored securely

## Support Resources

- **Documentation**: README.md, QUICKSTART.md
- **Health Check**: ./health-check.sh
- **Management**: ./manage.sh
- **Logs**: docker-compose logs [service]

## License

This configuration is provided as-is for production use.

---

**For questions or issues, check the logs first:**
```bash
docker-compose logs -f
```

**Everything working?**
✅ Your ChatBridge platform is ready for production use!
