#!/bin/bash
set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script version
VERSION="1.0.0"

echo -e "${BLUE}"
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
  echo -e "${BLUE}[INFO]${NC} $1"
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
WEBUI_NAME=AI Assistant Platform

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

  docker-compose -f docker/docker-compose.yml pull

  print_success "Docker images pulled successfully"
}

# Start services
start_services() {
  print_info "Starting services..."

  docker-compose -f docker/docker-compose.yml up -d

  print_success "Services started"
}

# Wait for services to be healthy
wait_for_services() {
  print_info "Waiting for services to become healthy..."

  local max_attempts=60
  local attempt=0

  while [ $attempt -lt $max_attempts ]; do
    if docker-compose -f docker/docker-compose.yml ps | grep -q "unhealthy"; then
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
  print_warning "Some services may still be starting. Check with: docker-compose -f docker/docker-compose.yml ps"
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
display_post_install() {
  print_info "Post-Installation Steps:"
  echo ""
  echo "1. DNS Configuration:"
  echo "   - Point ai.${DOMAIN} to this server's IP"
  echo "   - Point admin.${DOMAIN} to this server's IP"
  echo "   - Point traefik.${DOMAIN} to this server's IP"
  echo "   - Wait for DNS propagation (may take up to 48 hours)"
  echo ""
  echo "2. SSL Certificates:"
  echo "   - Let's Encrypt will automatically provision certificates"
  echo "   - Check Traefik logs: docker-compose logs traefik"
  echo ""
  echo "3. Create Admin Account:"
  echo "   - Visit https://ai.${DOMAIN}"
  echo "   - Create your admin account (first user becomes admin)"
  echo ""
  echo "4. Useful Commands:"
  echo "   - View logs: docker-compose -f docker/docker-compose.yml logs -f [service-name]"
  echo "   - Restart services: docker-compose -f docker/docker-compose.yml restart"
  echo "   - Stop services: docker-compose -f docker/docker-compose.yml down"
  echo "   - Update services: docker-compose -f docker/docker-compose.yml pull && docker-compose -f docker/docker-compose.yml up -d"
  echo "   - Backup manually: docker-compose -f docker/docker-compose.yml exec backup /backup-script.sh"
  echo ""
  echo "5. Security Recommendations:"
  echo "   - Enable firewall: sudo ufw enable"
  echo "   - Allow only ports 80, 443, and 22: sudo ufw allow 80,443,22/tcp"
  echo "   - Set up fail2ban for SSH protection"
  echo "   - Regularly update Docker images: docker-compose pull"
  echo "   - Monitor logs regularly"
  echo "   - Review backups in ./backups/ directory"
  echo ""
  echo "6. Monitoring:"
  echo "   - Check service status: docker-compose ps"
  echo "   - View resource usage: docker stats"
  echo "   - Check disk space: df -h"
  echo ""
  print_success "Setup complete! Your AI platform is ready to use."
  echo ""
}

# Backup existing installation
backup_existing() {
  if [ -f ".env" ] || [ -f "docker/docker-compose.yml" ]; then
    print_warning "Existing installation detected"
    read -p "Backup existing configuration? (Y/n): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Nn]$ ]]; then
      backup_dir="backup_$(date +%Y%m%d_%H%M%S)"
      mkdir -p "$backup_dir"
      cp -r .env docker "$backup_dir/" 2>/dev/null || true
      print_success "Backup created in $backup_dir"
    fi
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

  # Get configuration from user
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

  read -p "Proceed with installation? (Y/n): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    # Create directory structure
    create_directories

    # Generate environment file
    generate_env_file

    # Update configurations
    update_traefik_config
    update_litellm_config

    # Initialize Docker
    init_docker

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
