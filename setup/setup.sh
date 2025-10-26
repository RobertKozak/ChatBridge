#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color

# Script version
VERSION="1.0.0"

echo -e "${WHITE}"
cat <<"EOF"

   ╔═════════════════════════════════════════════════════════════════════════════════════╗
   ║                                                                                     ║
   ║     ██████╗██╗  ██╗ █████╗ ████████╗██████╗ ██████╗ ██╗██████╗  ██████╗ ███████╗    ║
   ║    ██╔════╝██║  ██║██╔══██╗╚══██╔══╝██╔══██╗██╔══██╗██║██╔══██╗██╔════╝ ██╔════╝    ║
   ║    ██║     ███████║███████║   ██║   ██████╔╝██████╔╝██║██║  ██║██║  ███╗█████╗      ║
   ║    ██║     ██╔══██║██╔══██║   ██║   ██╔══██╗██╔══██╗██║██║  ██║██║   ██║██╔══╝      ║
   ║    ╚██████╗██║  ██║██║  ██║   ██║   ██████╔╝██║  ██║██║██████╔╝╚██████╔╝███████╗    ║
   ║     ╚═════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝   ╚═════╝ ╚═╝  ╚═╝╚═╝╚═════╝  ╚═════╝ ╚══════╝    ║
   ║                                                                                     ║
   ║                        Bridge Multiple LLMs with Unified Chat                       ║
   ║                             Production-Ready AI Platform                            ║
   ║                                                                                     ║
   ╚═════════════════════════════════════════════════════════════════════════════════════╝

                                 🌉 Bridge Your Way to AI 🌉

EOF
echo -e "${NC}"
echo -e "${BLUE}Version: $VERSION${NC}\n"

# Function to print messages
print_info() {
  echo -e "\n${BLUE}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Function to generate random secure password
generate_password() {
  openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Function to generate API key
generate_api_key() {
  echo "sk-$(openssl rand -hex 24)"
}

# Function to check if command exists
command_exists() {
  command -v "$1" >/dev/null 2>&1
}

# Check prerequisites
check_prerequisites() {
  print_info "Checking prerequisites..."

  local missing_deps=()

  if ! command_exists docker; then
    missing_deps+=("docker")
  fi

  if ! command_exists docker-compose && ! docker compose version >/dev/null 2>&1; then
    missing_deps+=("docker-compose")
  fi

  if ! command_exists openssl; then
    missing_deps+=("openssl")
  fi

  if ! command_exists htpasswd; then
    missing_deps+=("apache2-utils (for htpasswd)")
  fi

  if ! command_exists curl; then
    missing_deps+=("curl")
  fi

  if [ ${#missing_deps[@]} -ne 0 ]; then
    print_error "Missing required dependencies:"
    for dep in "${missing_deps[@]}"; do
      echo "  - $dep"
    done
    echo ""
    print_info "Installation commands:"
    echo "  Ubuntu/Debian: sudo apt-get update && sudo apt-get install -y docker.io docker-compose openssl apache2-utils curl"
    echo "  RHEL/CentOS: sudo yum install -y docker docker-compose openssl httpd-tools curl"
    echo "  macOS: brew install docker docker-compose openssl curl"
    exit 1
  fi

  print_success "All prerequisites met"
}

# Check if running as root
check_root() {
  if [ "$EUID" -eq 0 ]; then
    print_warning "Running as root. It's recommended to run as a non-root user with Docker permissions."
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      exit 1
    fi
  fi
}

# Get domain from user
get_domain() {
  print_info "Domain Configuration"
  echo "Enter your domain name (e.g., example.com)"
  echo "Note: DNS must be configured to point to this server's IP"
  read -p "Domain: " DOMAIN

  if [ -z "$DOMAIN" ]; then
    print_error "Domain cannot be empty"
    exit 1
  fi

  print_success "Domain set to: $DOMAIN"
}

# Get email for Let's Encrypt
get_email() {
  print_info "Let's Encrypt Configuration"
  echo "Enter your email address for SSL certificate notifications"
  read -p "Email: " EMAIL

  if [ -z "$EMAIL" ]; then
    print_error "Email cannot be empty"
    exit 1
  fi

  print_success "Email set to: $EMAIL"
}

# Get API keys
get_api_keys() {
  print_info "API Keys Configuration"
  echo ""
  echo "Enter your API keys for the LLM providers you want to use."
  echo "Leave blank to skip a provider."
  echo ""

  read -p "OpenAI API Key (sk-...): " OPENAI_KEY
  read -p "Anthropic API Key (sk-ant-...): " ANTHROPIC_KEY
  read -p "Azure OpenAI API Key (optional): " AZURE_KEY

  if [ -z "$OPENAI_KEY" ] && [ -z "$ANTHROPIC_KEY" ]; then
    print_warning "No API keys provided. You'll need to add them later in the .env file."
  fi
}

# Create directory structure
create_directories() {
  print_info "Creating directory structure..."

  mkdir -p docker/traefik/dynamic
  mkdir -p docker/traefik/acme
  mkdir -p docker/litellm
  mkdir -p backups
  mkdir -p logs

  chmod 600 docker/traefik/acme
  chmod +x setup/backup-script.sh

  print_success "Directory structure created"
}

# Generate .env file
generate_env_file() {
  print_info "Generating secure .env file..."

  # Generate secure passwords
  POSTGRES_PASSWORD=$(generate_password)
  REDIS_PASSWORD=$(generate_password)
  LITELLM_MASTER_KEY=$(generate_api_key)
  LITELLM_SALT_KEY=$(generate_password)
  LITELLM_UI_PASSWORD=$(generate_password)
  WEBUI_SECRET_KEY=$(generate_password)

  # Generate Traefik basic auth
  TRAEFIK_PASSWORD=$(generate_password)
  TRAEFIK_HASH=$(htpasswd -nb admin "$TRAEFIK_PASSWORD" | sed -e s/\\$/\\$\\$/g)

  # Create .env file
  cat >.env <<EOF
# Generated by setup script on $(date)
# KEEP THIS FILE SECURE AND NEVER COMMIT TO VERSION CONTROL

# Domain Configuration
DOMAIN=${DOMAIN}

# Traefik Configuration
TRAEFIK_BASIC_AUTH=${TRAEFIK_HASH}

# PostgreSQL Configuration
POSTGRES_DB=postgres
POSTGRES_USER=postgres
POSTGRES_PASSWORD=${POSTGRES_PASSWORD}
LITELLM_DB=litellm
OPENWEBUI_DB=openwebui

# Redis Configuration
REDIS_PASSWORD=${REDIS_PASSWORD}

# LiteLLM Configuration
LITELLM_MASTER_KEY=${LITELLM_MASTER_KEY}
LITELLM_SALT_KEY=${LITELLM_SALT_KEY}
LITELLM_UI_USERNAME=admin
LITELLM_UI_PASSWORD=${LITELLM_UI_PASSWORD}

# Open WebUI Configuration
WEBUI_SECRET_KEY=${WEBUI_SECRET_KEY}
ENABLE_SIGNUP=false
DEFAULT_USER_ROLE=user
WEBUI_NAME="AI Assistant Platform"

# Model Configuration
MODEL_FILTER_LIST=gpt-4,gpt-3.5-turbo,claude-3-opus,claude-3-sonnet
TASK_MODEL=gpt-3.5-turbo
TITLE_MODEL=gpt-3.5-turbo

# API Keys
OPENAI_API_KEY=${OPENAI_KEY}
ANTHROPIC_API_KEY=${ANTHROPIC_KEY}
AZURE_API_KEY=${AZURE_KEY}
AZURE_API_BASE=
AZURE_API_VERSION=

# Backup Configuration
BACKUP_KEEP_DAYS=7

# Optional configurations (leave empty if not used)
WEBHOOK_URL=
SEARCH_PROMPT_TEMPLATE="Generate a concise and focused web search query based on the user's question or conversation context. Return only the search query."
SMTP_HOST=
SMTP_PORT=587
SMTP_USER=
SMTP_PASSWORD=
SMTP_FROM=
EOF

  chmod 600 .env

  print_success ".env file generated with secure credentials"
}

# Update Traefik configuration with domain and email
update_traefik_config() {
  print_info "Updating Traefik configuration..."

  # Cross-platform sed compatibility (works on both Linux and macOS)
  if sed --version >/dev/null 2>&1; then
    # GNU sed (Linux)
    sed -i "s/your-domain.com/${DOMAIN}/g" docker/traefik/traefik.yml
    sed -i "s/admin@your-domain.com/${EMAIL}/g" docker/traefik/traefik.yml
  else
    # BSD sed (macOS)
    sed -i '' "s/your-domain.com/${DOMAIN}/g" docker/traefik/traefik.yml
    sed -i '' "s/admin@your-domain.com/${EMAIL}/g" docker/traefik/traefik.yml
  fi

  print_success "Traefik configuration updated"
}

# Update LiteLLM config based on provided API keys
update_litellm_config() {
  print_info "Updating LiteLLM configuration..."

  # This is already set up to read from environment variables
  # Just ensure the file exists
  if [ ! -f "docker/litellm/config.yaml" ]; then
    print_error "LiteLLM config file not found"
    exit 1
  fi

  print_success "LiteLLM configuration verified"
}

# Initialize Docker Swarm (optional, for future scaling)
init_docker() {
  print_info "Checking Docker configuration..."

  # Ensure Docker daemon is running
  if ! docker info >/dev/null 2>&1; then
    print_error "Docker daemon is not running. Please start Docker and try again."
    exit 1
  fi

  print_success "Docker is running"
}

# Pull Docker images
pull_images() {
  print_info "Pulling Docker images (this may take several minutes)..."

  docker-compose -f docker/docker-compose.yml --env-file .env pull

  print_success "Docker images pulled successfully"
}

# Start services
start_services() {
  print_info "Starting services..."

  docker-compose -f docker/docker-compose.yml --env-file .env up -d

  print_success "Services started"
}

# Wait for services to be healthy
wait_for_services() {
  print_info "Waiting for services to become healthy..."

  local max_attempts=60
  local attempt=0

  while [ $attempt -lt $max_attempts ]; do
    if docker-compose -f docker/docker-compose.yml --env-file .env ps | grep -q "unhealthy"; then
      attempt=$((attempt + 1))
      echo -n "."
      sleep 5
    else
      echo ""
      print_success "All services are healthy"
      return 0
    fi
  done

  echo ""
  print_warning "Some services may still be starting. Check with: docker-compose -f docker/docker-compose.yml --env-file .env ps"
}

# Display credentials
display_credentials() {
  echo ""
  echo -e "${GREEN}╔═══════════════════════════════════════════════════════════╗${NC}"
  echo -e "${GREEN}║           Installation Completed Successfully!            ║${NC}"
  echo -e "${GREEN}╚═══════════════════════════════════════════════════════════╝${NC}"
  echo ""
  print_info "Your credentials (SAVE THESE SECURELY):"
  echo ""
  echo -e "${YELLOW}Open WebUI:${NC}"
  echo "  URL: https://ai.${DOMAIN}"
  echo "  First user will become admin - create account now!"
  echo ""
  echo -e "${YELLOW}LiteLLM Proxy:${NC}"
  echo "  URL: https://admin.${DOMAIN}"
  echo "  API Endpoint: https://admin.${DOMAIN}/v1"
  echo "  Master Key: ${LITELLM_MASTER_KEY}"
  echo "  UI Username: admin"
  echo "  UI Password: ${LITELLM_UI_PASSWORD}"
  echo ""
  echo -e "${YELLOW}Traefik Dashboard:${NC}"
  echo "  URL: https://traefik.${DOMAIN}"
  echo "  Username: admin"
  echo "  Password: ${TRAEFIK_PASSWORD}"
  echo ""
  echo -e "${YELLOW}PostgreSQL:${NC}"
  echo "  Host: localhost:5432 (internal only)"
  echo "  Username: postgres"
  echo "  Password: ${POSTGRES_PASSWORD}"
  echo ""
  print_warning "All credentials are also saved in the .env file"
  print_warning "Keep the .env file secure and never commit it to version control"
  echo ""
}

# Display post-installation steps
# Check DNS configuration
check_dns() {
  print_info "Checking DNS configuration..."
  echo ""

  # Check if using Cloudflare Tunnel
  local using_cloudflare_tunnel=false
  if [ -f "docker/cloudflared/config.yml" ]; then
    using_cloudflare_tunnel=true
    print_info "Cloudflare Tunnel detected - DNS should point to Cloudflare IPs"
  fi

  local all_configured=true
  local subdomains=("ai" "admin" "traefik")

  for subdomain in "${subdomains[@]}"; do
    local fqdn="${subdomain}.${DOMAIN}"
    print_info "Checking DNS for ${fqdn}..."

    # Try to resolve the domain
    local resolved_ip=$(dig +short "${fqdn}" @8.8.8.8 2>/dev/null | grep -E '^[0-9.]+$' | head -1)

    if [ -z "$resolved_ip" ]; then
      print_warning "  ⚠️  ${fqdn} - Not configured"
      if [ "$using_cloudflare_tunnel" = true ]; then
        echo "      Action: Configure DNS in Cloudflare Dashboard"
      else
        SERVER_IP=$(curl -s4 ifconfig.me 2>/dev/null || curl -s4 icanhazip.com 2>/dev/null || echo "your-server-ip")
        echo "      Action: Point ${fqdn} to ${SERVER_IP}"
      fi
      all_configured=false
    else
      # Check if it's a Cloudflare IP (common ranges)
      if [ "$using_cloudflare_tunnel" = true ]; then
        # Cloudflare IP ranges: 172.64-71.x.x, 104.16-31.x.x, 108.162.x.x, etc.
        if [[ "$resolved_ip" =~ ^172\.(6[4-9]|7[0-1])\. ]] || \
           [[ "$resolved_ip" =~ ^104\.(1[6-9]|2[0-9]|3[0-1])\. ]] || \
           [[ "$resolved_ip" =~ ^108\.162\. ]] || \
           [[ "$resolved_ip" =~ ^141\.101\. ]] || \
           [[ "$resolved_ip" =~ ^162\.158\. ]] || \
           [[ "$resolved_ip" =~ ^173\.245\. ]] || \
           [[ "$resolved_ip" =~ ^188\.114\. ]] || \
           [[ "$resolved_ip" =~ ^190\.93\. ]] || \
           [[ "$resolved_ip" =~ ^197\.234\. ]] || \
           [[ "$resolved_ip" =~ ^198\.41\. ]]; then
          print_success "  ✓  ${fqdn} - Correctly configured (Cloudflare: ${resolved_ip})"
        else
          print_warning "  ⚠️  ${fqdn} - Points to ${resolved_ip} (expected Cloudflare IP)"
          echo "      Action: Update DNS to point to Cloudflare (via Cloudflare Dashboard)"
          all_configured=false
        fi
      else
        # Direct deployment - check against server IP
        SERVER_IP=$(curl -s4 ifconfig.me 2>/dev/null || curl -s4 icanhazip.com 2>/dev/null || echo "unknown")
        if [ "$SERVER_IP" != "unknown" ] && [ "$resolved_ip" != "$SERVER_IP" ]; then
          print_warning "  ⚠️  ${fqdn} - Points to ${resolved_ip} (expected: ${SERVER_IP})"
          echo "      Action: Update DNS to point to ${SERVER_IP}"
          all_configured=false
        else
          print_success "  ✓  ${fqdn} - Correctly configured (${resolved_ip})"
        fi
      fi
    fi
  done

  echo ""

  if [ "$all_configured" = true ]; then
    print_success "All DNS records are correctly configured!"
    return 0
  else
    print_warning "DNS configuration incomplete"
    echo ""
    if [ "$using_cloudflare_tunnel" = true ]; then
      echo "To configure DNS for Cloudflare Tunnel:"
      echo "  1. Verify tunnel is running: cloudflared tunnel list"
      echo "  2. Check DNS routes: cloudflared tunnel route list"
      echo "  3. If routes are missing, add them:"
      for subdomain in "${subdomains[@]}"; do
        echo "     cloudflared tunnel route dns <tunnel-name> ${subdomain}.${DOMAIN}"
      done
    else
      SERVER_IP=$(curl -s4 ifconfig.me 2>/dev/null || curl -s4 icanhazip.com 2>/dev/null || echo "your-server-ip")
      echo "To configure DNS:"
      echo "  1. Log in to your domain registrar or DNS provider"
      echo "  2. Add/Update A records for the following subdomains:"
      for subdomain in "${subdomains[@]}"; do
        echo "     - ${subdomain}.${DOMAIN}  →  ${SERVER_IP}"
      done
      echo ""
      echo "  3. Wait for DNS propagation (usually 5-60 minutes, max 48 hours)"
    fi
    echo ""
    echo "  4. Re-run this script to verify DNS configuration"
    echo ""
    read -p "Continue anyway? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
      print_info "Installation paused. Please configure DNS and run again."
      exit 0
    else
      echo ""
      print_warning "Continuing with incorrect DNS configuration"
      echo ""
      echo "⚠️  IMPORTANT: SSL certificates will NOT work until DNS is configured!"
      echo ""
      echo "What happens next:"
      echo "  - Services will start but won't be accessible via domain names"
      echo "  - Traefik will fail to obtain SSL certificates from Let's Encrypt"
      echo "  - You'll see certificate errors in the logs"
      echo ""
      echo "After configuring DNS (usually 5-60 minutes):"
      echo "  1. Verify DNS: dig ai.${DOMAIN} (should show ${SERVER_IP})"
      echo "  2. Restart Traefik: docker-compose -f docker/docker-compose.yml restart traefik"
      echo "  3. Check logs: docker-compose -f docker/docker-compose.yml logs -f traefik"
      echo "  4. Wait for 'Certificate obtained' message"
      echo ""
      read -p "Press Enter to continue with installation..."
      echo ""
    fi
    return 1
  fi
}

display_post_install() {
  print_info "Post-Installation Steps:"
  echo ""
  echo "1. SSL Certificates:"
  echo "   - Let's Encrypt will automatically provision certificates"
  echo "   - Check Traefik logs: docker-compose -f docker/docker-compose.yml logs traefik"
  echo ""
  echo "2. Create Admin Account:"
  echo "   - Visit https://ai.${DOMAIN}"
  echo "   - Create your admin account (first user becomes admin)"
  echo ""
  echo "3. Useful Commands:"
  echo "   - View logs: docker-compose -f docker/docker-compose.yml logs -f [service-name]"
  echo "   - Restart services: docker-compose -f docker/docker-compose.yml restart"
  echo "   - Stop services: docker-compose -f docker/docker-compose.yml down"
  echo "   - Update services: docker-compose -f docker/docker-compose.yml pull && docker-compose -f docker/docker-compose.yml up -d"
  echo "   - Backup manually: docker-compose -f docker/docker-compose.yml exec backup /backup-script.sh"
  echo ""
  echo "4. Security Recommendations:"
  echo "   - Enable firewall: sudo ufw enable"
  echo "   - Allow only ports 80, 443, and 22: sudo ufw allow 80,443,22/tcp"
  echo "   - Set up fail2ban for SSH protection"
  echo "   - Regularly update Docker images: docker-compose pull"
  echo "   - Monitor logs regularly"
  echo "   - Review backups in ./backups/ directory"
  echo ""
  echo "5. Monitoring:"
  echo "   - Check service status: docker-compose ps"
  echo "   - View resource usage: docker stats"
  echo "   - Check disk space: df -h"
  echo ""
  print_success "Setup complete! Your AI platform is ready to use."
  echo ""
}

# Load existing configuration
load_existing_config() {
  if [ -f ".env" ]; then
    print_info "Loading existing configuration..."

    # Source the .env file to load variables
    set -a
    source .env 2>/dev/null || true
    set +a

    # Extract values we need
    DOMAIN=${DOMAIN:-}
    # Email is not stored in .env, extract from traefik config
    EMAIL=$(grep "email:" docker/traefik/traefik.yml 2>/dev/null | sed 's/.*email: //' | tr -d '"' || echo "admin@${DOMAIN}")
    OPENAI_KEY=${OPENAI_API_KEY:-}
    ANTHROPIC_KEY=${ANTHROPIC_API_KEY:-}
    AZURE_KEY=${AZURE_API_KEY:-}

    print_success "Existing configuration loaded"
    return 0
  else
    return 1
  fi
}

# Backup existing installation
backup_existing() {
  if [ -f ".env" ]; then
    print_warning "Existing installation detected"
    echo ""
    echo "Choose an option:"
    echo "  1) Continue with previous installation (use existing settings)"
    echo "  2) Start fresh (re-enter all configuration)"
    echo ""
    read -p "Choice [1]: " choice
    choice=${choice:-1}
    echo ""

    if [ "$choice" = "1" ]; then
      print_info "Continuing with existing installation..."
      USE_EXISTING_CONFIG=true

      # Load existing configuration
      if load_existing_config; then
        print_success "Using existing configuration"
        echo "  Domain: ${DOMAIN}"
        echo "  OpenAI API: ${OPENAI_KEY:+Configured}"
        echo "  Anthropic API: ${ANTHROPIC_KEY:+Configured}"
        echo ""
      else
        print_error "Failed to load existing configuration. Please start fresh."
        exit 1
      fi
    else
      print_info "Starting fresh installation..."
      USE_EXISTING_CONFIG=false

      # Ask about backup
      read -p "Backup existing configuration? (Y/n): " -n 1 -r
      echo
      if [[ ! $REPLY =~ ^[Nn]$ ]]; then
        backup_dir="backups/config_backup_$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$backup_dir"
        cp -r .env docker "$backup_dir/" 2>/dev/null || true
        print_success "Backup created in $backup_dir"
      fi
    fi
  else
    USE_EXISTING_CONFIG=false
  fi
}

# Main installation flow
main() {
  print_info "Starting installation process..."
  echo ""

  # Check if running as root
  check_root

  # Check prerequisites
  check_prerequisites

  # Backup existing installation
  backup_existing

  # Get configuration from user (skip if using existing)
  if [ "$USE_EXISTING_CONFIG" != "true" ]; then
    get_domain
    get_email
    get_api_keys

    echo ""
    print_info "Configuration summary:"
    echo "  Domain: ${DOMAIN}"
    echo "  Email: ${EMAIL}"
    echo "  OpenAI: ${OPENAI_KEY:+Configured}"
    echo "  Anthropic: ${ANTHROPIC_KEY:+Configured}"
    echo ""
  fi

  read -p "Proceed with installation? (Y/n): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    # Create directory structure
    create_directories

    # Generate environment file (skip if using existing)
    if [ "$USE_EXISTING_CONFIG" != "true" ]; then
      generate_env_file
      # Update configurations
      update_traefik_config
      update_litellm_config
    else
      print_info "Using existing .env and configuration files"
    fi

    # Initialize Docker
    init_docker

    # Check DNS configuration (only if using a real domain, not localhost)
    if [[ ! "$DOMAIN" =~ ^(localhost|127\.0\.0\.1|.*\.local)$ ]]; then
      check_dns || true  # Don't exit script if DNS check fails
    fi

    # Pull images
    pull_images

    # Start services
    start_services

    # Wait for services
    wait_for_services

    # Display credentials
    display_credentials

    # Display post-installation steps
    display_post_install
  else
    print_info "Installation cancelled"
    exit 0
  fi
}

# Run main function
main "$@"
