#!/bin/bash

# Utility script for common management tasks

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
WHITE='\033[1;37m'
NC='\033[0m'

print_header() {
  clear
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
   ║                                 Management Tool                                     ║
   ║                                                                                     ║
   ╚═════════════════════════════════════════════════════════════════════════════════════╝

EOF
  echo -e "${NC}"
}

print_menu() {
  echo -e "${YELLOW}Available Commands:${NC}"
  echo ""
  echo "  1) start           - Start all services"
  echo "  2) stop            - Stop all services"
  echo "  3) restart         - Restart all services"
  echo "  4) status          - Show service status"
  echo "  5) logs            - View logs (all services)"
  echo "  6) health          - Run health check"
  echo "  7) backup          - Create manual backup"
  echo "  8) restore         - Restore from backup"
  echo "  9) update          - Update all services"
  echo " 10) reset-password  - Reset admin password"
  echo " 11) add-user        - Add new user to Open WebUI"
  echo " 12) ollama-pull     - Pull Ollama model"
  echo " 13) ollama-list     - List Ollama models"
  echo " 14) ollama-remove   - Remove Ollama model"
  echo " 15) cleanup         - Clean up old logs and backups"
  echo " 16) ssl-renew       - Force SSL certificate renewal"
  echo " 17) export-config   - Export configuration"
  echo " 18) import-config   - Import configuration"
  echo ""
  echo "  0) exit            - Exit"
  echo ""
}

start_services() {
  echo -e "${BLUE}Starting all services...${NC}"
  docker-compose -f docker/docker-compose.yml --env-file .env up -d
  echo -e "${GREEN}✓ Services started${NC}"
  docker-compose -f docker/docker-compose.yml --env-file .env ps
}

stop_services() {
  echo -e "${BLUE}Stopping all services...${NC}"
  docker-compose -f docker/docker-compose.yml --env-file .env down
  echo -e "${GREEN}✓ Services stopped${NC}"
}

restart_services() {
  echo -e "${BLUE}Restarting all services...${NC}"
  docker-compose -f docker/docker-compose.yml --env-file .env restart
  echo -e "${GREEN}✓ Services restarted${NC}"
  docker-compose -f docker/docker-compose.yml --env-file .env ps
}

show_status() {
  echo -e "${BLUE}Service Status:${NC}"
  docker-compose -f docker/docker-compose.yml --env-file .env ps
  echo ""
  echo -e "${BLUE}Resource Usage:${NC}"
  docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}"
}

view_logs() {
  echo -e "${BLUE}Select service to view logs:${NC}"
  echo "  1) All services"
  echo "  2) Open WebUI"
  echo "  3) LiteLLM"
  echo "  4) Traefik"
  echo "  5) PostgreSQL"
  echo "  6) Redis"
  echo "  7) Ollama"
  echo ""
  read -p "Choice [1]: " choice
  choice=${choice:-1}

  case $choice in
  1) docker-compose -f docker/docker-compose.yml --env-file .env logs -f ;;
  2) docker-compose -f docker/docker-compose.yml --env-file .env logs -f open-webui ;;
  3) docker-compose -f docker/docker-compose.yml --env-file .env logs -f litellm ;;
  4) docker-compose -f docker/docker-compose.yml --env-file .env logs -f traefik ;;
  5) docker-compose -f docker/docker-compose.yml --env-file .env logs -f postgres ;;
  6) docker-compose -f docker/docker-compose.yml --env-file .env logs -f redis ;;
  7) docker-compose -f docker/docker-compose.yml --env-file .env logs -f ollama ;;
  *) echo "Invalid choice" ;;
  esac
}

run_health_check() {
  if [ -f "setup/health-check.sh" ]; then
    bash setup/health-check.sh
  else
    echo -e "${RED}setup/health-check.sh not found${NC}"
  fi
}

create_backup() {
  echo -e "${BLUE}Creating manual backup...${NC}"
  docker-compose -f docker/docker-compose.yml --env-file .env exec backup /backup-script.sh
  echo -e "${GREEN}✓ Backup completed${NC}"
  echo ""
  echo "Recent backups:"
  ls -lht backups/*.sql.gz 2>/dev/null | head -n 5 || echo "No backups found"
}

restore_backup() {
  echo -e "${BLUE}Available backups:${NC}"
  echo ""

  backups=($(ls -t backups/*.sql.gz 2>/dev/null))

  if [ ${#backups[@]} -eq 0 ]; then
    echo -e "${RED}No backups found${NC}"
    return
  fi

  for i in "${!backups[@]}"; do
    size=$(du -h "${backups[$i]}" | cut -f1)
    # Cross-platform stat compatibility
    if stat --version >/dev/null 2>&1; then
      # GNU stat (Linux)
      date=$(stat -c %y "${backups[$i]}" | cut -d' ' -f1,2 | cut -d. -f1)
    else
      # BSD stat (macOS)
      date=$(stat -f "%Sm" -t "%Y-%m-%d %H:%M:%S" "${backups[$i]}")
    fi
    echo "  $((i + 1))) $(basename ${backups[$i]}) - $size - $date"
  done

  echo ""
  read -p "Select backup to restore [1]: " choice
  choice=${choice:-1}

  if [ $choice -lt 1 ] || [ $choice -gt ${#backups[@]} ]; then
    echo -e "${RED}Invalid choice${NC}"
    return
  fi

  backup_file="${backups[$((choice - 1))]}"
  db_name=$(basename "$backup_file" | cut -d_ -f1)

  echo -e "${YELLOW}⚠ Warning: This will overwrite the current $db_name database${NC}"
  read -p "Are you sure? (yes/NO): " confirm

  if [ "$confirm" != "yes" ]; then
    echo "Restore cancelled"
    return
  fi

  echo -e "${BLUE}Restoring $db_name from $backup_file...${NC}"

  # Stop services using the database
  docker-compose -f docker/docker-compose.yml --env-file .env stop litellm open-webui

  # Restore database
  gunzip <"$backup_file" | docker-compose -f docker/docker-compose.yml --env-file .env exec -T postgres psql -U postgres -d "$db_name"

  # Restart services
  docker-compose -f docker/docker-compose.yml --env-file .env start litellm open-webui

  echo -e "${GREEN}✓ Restore completed${NC}"
}

update_services() {
  echo -e "${BLUE}Updating all services...${NC}"
  echo ""

  echo "1. Creating backup before update..."
  create_backup

  echo ""
  echo "2. Pulling latest images..."
  docker-compose -f docker/docker-compose.yml --env-file .env pull

  echo ""
  echo "3. Restarting services with new images..."
  docker-compose -f docker/docker-compose.yml --env-file .env up -d

  echo ""
  echo -e "${GREEN}✓ Update completed${NC}"
  docker-compose -f docker/docker-compose.yml --env-file .env ps
}

reset_password() {
  echo -e "${BLUE}Reset Admin Password${NC}"
  echo ""

  # Generate new password
  new_password=$(openssl rand -base64 16)

  # Update LiteLLM UI password (cross-platform sed)
  if grep -q "LITELLM_UI_PASSWORD" .env; then
    if sed --version >/dev/null 2>&1; then
      sed -i "s/LITELLM_UI_PASSWORD=.*/LITELLM_UI_PASSWORD=${new_password}/" .env
    else
      sed -i '' "s/LITELLM_UI_PASSWORD=.*/LITELLM_UI_PASSWORD=${new_password}/" .env
    fi
    docker-compose -f docker/docker-compose.yml --env-file .env restart litellm
    echo -e "${GREEN}✓ LiteLLM UI password reset${NC}"
    echo "  New password: $new_password"
  fi

  # Update Traefik password
  read -p "Also reset Traefik dashboard password? (y/N): " reset_traefik
  if [[ $reset_traefik =~ ^[Yy]$ ]]; then
    traefik_pass=$(openssl rand -base64 16)
    traefik_hash=$(htpasswd -nb admin "$traefik_pass" | sed -e s/\\$/\\$\\$/g)
    if sed --version >/dev/null 2>&1; then
      sed -i "s|TRAEFIK_BASIC_AUTH=.*|TRAEFIK_BASIC_AUTH=${traefik_hash}|" .env
    else
      sed -i '' "s|TRAEFIK_BASIC_AUTH=.*|TRAEFIK_BASIC_AUTH=${traefik_hash}|" .env
    fi
    docker-compose -f docker/docker-compose.yml --env-file .env restart traefik
    echo -e "${GREEN}✓ Traefik password reset${NC}"
    echo "  New password: $traefik_pass"
  fi

  echo ""
  echo -e "${YELLOW}⚠ Save these passwords securely!${NC}"
}

ollama_pull_model() {
  echo -e "${BLUE}Pull Ollama Model${NC}"
  echo ""
  echo "Popular models:"
  echo "  - llama2, llama3, llama3.1"
  echo "  - mistral, mixtral"
  echo "  - codellama, phi, gemma, qwen"
  echo ""
  read -p "Enter model name to pull: " MODEL_NAME

  if [ -z "$MODEL_NAME" ]; then
    echo -e "${RED}Model name cannot be empty${NC}"
    return 1
  fi

  echo -e "${BLUE}Pulling model: ${MODEL_NAME}${NC}"
  docker exec chatbridge-ollama ollama pull "$MODEL_NAME"

  if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Model ${MODEL_NAME} pulled successfully${NC}"
  else
    echo -e "${RED}✗ Failed to pull model${NC}"
  fi
}

ollama_list_models() {
  echo -e "${BLUE}Installed Ollama Models${NC}"
  echo ""
  docker exec chatbridge-ollama ollama list
}

ollama_remove_model() {
  echo -e "${BLUE}Remove Ollama Model${NC}"
  echo ""
  echo "Currently installed models:"
  docker exec chatbridge-ollama ollama list
  echo ""
  read -p "Enter model name to remove: " MODEL_NAME

  if [ -z "$MODEL_NAME" ]; then
    echo -e "${RED}Model name cannot be empty${NC}"
    return 1
  fi

  read -p "Are you sure you want to remove ${MODEL_NAME}? (y/N): " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    docker exec chatbridge-ollama ollama rm "$MODEL_NAME"

    if [ $? -eq 0 ]; then
      echo -e "${GREEN}✓ Model ${MODEL_NAME} removed${NC}"
    else
      echo -e "${RED}✗ Failed to remove model${NC}"
    fi
  else
    echo "Cancelled"
  fi
}

cleanup_old_files() {
  echo -e "${BLUE}Cleaning up old files...${NC}"
  echo ""

  # Clean old backups (keep last 7 days)
  echo "Cleaning backups older than 7 days..."
  find backups -name "*.sql.gz" -type f -mtime +7 -delete 2>/dev/null || true

  # Clean Docker system
  read -p "Clean Docker system (remove unused images/containers)? (y/N): " clean_docker
  if [[ $clean_docker =~ ^[Yy]$ ]]; then
    docker system prune -f
  fi

  # Show disk usage
  echo ""
  echo -e "${BLUE}Current disk usage:${NC}"
  df -h /

  echo ""
  echo -e "${GREEN}✓ Cleanup completed${NC}"
}

force_ssl_renewal() {
  echo -e "${BLUE}Forcing SSL certificate renewal...${NC}"

  # Remove old certificates
  docker-compose -f docker/docker-compose.yml --env-file .env stop traefik
  rm -f docker/traefik/acme/acme.json
  docker-compose -f docker/docker-compose.yml --env-file .env start traefik

  echo ""
  echo "Waiting for certificate provisioning..."
  sleep 10

  docker-compose -f docker/docker-compose.yml --env-file .env logs traefik | tail -n 20

  echo ""
  echo -e "${GREEN}✓ Certificate renewal initiated${NC}"
  echo "Check Traefik logs for status: docker-compose -f docker/docker-compose.yml --env-file .env logs -f traefik"
}

export_configuration() {
  echo -e "${BLUE}Exporting configuration...${NC}"

  export_dir="export_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$export_dir"

  # Copy configuration files (excluding sensitive data)
  cp docker-compose.yml "$export_dir/"
  cp .env.example "$export_dir/"
  cp -r traefik "$export_dir/" 2>/dev/null || true
  cp -r litellm "$export_dir/" 2>/dev/null || true

  # Create tarball
  tar czf "${export_dir}.tar.gz" "$export_dir"
  rm -rf "$export_dir"

  echo -e "${GREEN}✓ Configuration exported to ${export_dir}.tar.gz${NC}"
}

import_configuration() {
  echo -e "${BLUE}Import Configuration${NC}"
  echo ""
  echo "Available exports:"
  ls -lht export_*.tar.gz 2>/dev/null | head -n 5 || echo "No exports found"
  echo ""

  read -p "Enter export file name: " export_file

  if [ ! -f "$export_file" ]; then
    echo -e "${RED}File not found${NC}"
    return
  fi

  echo -e "${YELLOW}⚠ This will overwrite existing configuration${NC}"
  read -p "Continue? (yes/NO): " confirm

  if [ "$confirm" != "yes" ]; then
    echo "Import cancelled"
    return
  fi

  tar xzf "$export_file"

  echo -e "${GREEN}✓ Configuration imported${NC}"
  echo "Review changes and update .env with your credentials"
}

# Main menu loop
main() {
  print_header

  while true; do
    print_menu
    read -p "Select option [0]: " choice
    echo ""

    case $choice in
    1) start_services ;;
    2) stop_services ;;
    3) restart_services ;;
    4) show_status ;;
    5) view_logs ;;
    6) run_health_check ;;
    7) create_backup ;;
    8) restore_backup ;;
    9) update_services ;;
    10) reset_password ;;
    11) echo "User management is done through Open WebUI interface" ;;
    12) ollama_pull_model ;;
    13) ollama_list_models ;;
    14) ollama_remove_model ;;
    15) cleanup_old_files ;;
    16) force_ssl_renewal ;;
    17) export_configuration ;;
    18) import_configuration ;;
    0 | "")
      echo "Exiting..."
      exit 0
      ;;
    *) echo -e "${RED}Invalid option${NC}" ;;
    esac

    echo ""
    read -p "Press Enter to continue..."
    print_header
  done
}

# Check if running from correct directory
if [ ! -f "docker/docker-compose.yml" ]; then
  echo -e "${RED}Error: docker/docker-compose.yml not found${NC}"
  echo "Please run this script from the installation directory"
  exit 1
fi

main "$@"
