#!/bin/bash

# Health check and monitoring script for LiteLLM + Open WebUI deployment

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_header() {
  echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
  echo -e "${BLUE}║    ChatBridge Health & Monitoring Dashboard    ║${NC}"
  echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}"
  echo ""
}

print_section() {
  echo -e "\n${BLUE}━━━ $1 ━━━${NC}"
}

check_service() {
  local service=$1
  local status=$(docker-compose -f docker/docker-compose.yml --env-file .env ps -q $service 2>/dev/null)

  if [ -z "$status" ]; then
    echo -e "  ${RED}✗${NC} $service: Not running"
    return 1
  fi

  local health=$(docker inspect --format='{{.State.Health.Status}}' $(docker-compose -f docker/docker-compose.yml --env-file .env ps -q $service) 2>/dev/null || echo "no-health-check")

  if [ "$health" = "healthy" ]; then
    echo -e "  ${GREEN}✓${NC} $service: Healthy"
    return 0
  elif [ "$health" = "no-health-check" ]; then
    local running=$(docker inspect --format='{{.State.Running}}' $(docker-compose -f docker/docker-compose.yml --env-file .env ps -q $service) 2>/dev/null)
    if [ "$running" = "true" ]; then
      echo -e "  ${GREEN}✓${NC} $service: Running"
      return 0
    else
      echo -e "  ${RED}✗${NC} $service: Not running"
      return 1
    fi
  else
    echo -e "  ${YELLOW}⚠${NC} $service: $health"
    return 1
  fi
}

check_url() {
  local name=$1
  local url=$2

  if curl -s -o /dev/null -w "%{http_code}" --max-time 5 "$url" | grep -q "200\|301\|302\|401"; then
    echo -e "  ${GREEN}✓${NC} $name: Accessible"
    return 0
  else
    echo -e "  ${RED}✗${NC} $name: Not accessible"
    return 1
  fi
}

print_header

# Check if Docker Compose is available
if ! command -v docker-compose -f docker/docker-compose.yml --env-file .env &>/dev/null; then
  echo -e "${RED}Error: docker-compose -f docker/docker/docker-compose.yml not found${NC}"
  exit 1
fi

# Service Status
print_section "Service Status"
check_service "traefik"
check_service "postgres"
check_service "redis"
check_service "litellm"
check_service "open-webui"
check_service "backup"

# URL Accessibility
print_section "Endpoint Accessibility"
if [ -f ".env" ]; then
  source .env
  check_url "Open WebUI" "https://ai.${DOMAIN}"
  check_url "LiteLLM API" "https://admin.${DOMAIN}/health"
  check_url "Traefik Dashboard" "https://traefik.${DOMAIN}"
else
  echo -e "  ${YELLOW}⚠${NC} .env file not found - skipping URL checks"
fi

# Resource Usage
print_section "Resource Usage"
echo -e "\n${YELLOW}Container Resources:${NC}"
docker stats --no-stream --format "table {{.Name}}\t{{.CPUPerc}}\t{{.MemUsage}}\t{{.NetIO}}" | head -n 7

# Disk Usage
print_section "Disk Usage"
echo -e "\n${YELLOW}Disk Space:${NC}"
df -h / | tail -n 1 | awk '{print "  Total: "$2"  Used: "$3" ("$5")  Available: "$4}'

echo -e "\n${YELLOW}Docker Volumes:${NC}"
docker system df -v | grep -A 20 "Local Volumes" | grep -E "litellm|postgres|redis|openwebui" || echo "  No volumes found"

# Database Status
print_section "Database Status"
if docker-compose -f docker/docker-compose.yml --env-file .env ps postgres | grep -q "Up"; then
  echo -e "\n${YELLOW}PostgreSQL:${NC}"

  # Connection count
  conn_count=$(docker-compose -f docker/docker-compose.yml --env-file .env exec -T postgres psql -U postgres -t -c "SELECT count(*) FROM pg_stat_activity;" 2>/dev/null | tr -d ' ')
  max_conn=$(docker-compose -f docker/docker-compose.yml --env-file .env exec -T postgres psql -U postgres -t -c "SHOW max_connections;" 2>/dev/null | tr -d ' ')
  echo -e "  Connections: $conn_count / $max_conn"

  # Database sizes
  echo -e "\n  Database Sizes:"
  docker-compose -f docker/docker-compose.yml --env-file .env exec -T postgres psql -U postgres -c "SELECT datname, pg_size_pretty(pg_database_size(datname)) as size FROM pg_database WHERE datname IN ('litellm', 'openwebui', 'postgres');" 2>/dev/null | tail -n +3 | head -n -2 | while read line; do
    echo "    $line"
  done
else
  echo -e "  ${RED}PostgreSQL not running${NC}"
fi

# Redis Status
if docker-compose -f docker/docker-compose.yml --env-file .env ps redis | grep -q "Up"; then
  echo -e "\n${YELLOW}Redis:${NC}"
  redis_info=$(docker-compose -f docker/docker-compose.yml --env-file .env exec -T redis redis-cli -a "${REDIS_PASSWORD}" INFO stats 2>/dev/null | grep -E "keyspace_hits|keyspace_misses" || echo "  Unable to fetch Redis stats")
  echo "  $redis_info"
else
  echo -e "  ${RED}Redis not running${NC}"
fi

# Recent Logs
print_section "Recent Errors (Last 50 lines)"
docker-compose -f docker/docker-compose.yml --env-file .env logs --tail=50 2>&1 | grep -i "error\|fatal\|exception" | tail -n 10 || echo "  No recent errors found"

# Backup Status
print_section "Backup Status"
if [ -d "backups" ]; then
  backup_count=$(find backups -name "*.sql.gz" -type f | wc -l)
  if [ $backup_count -gt 0 ]; then
    latest_backup=$(ls -t backups/*.sql.gz 2>/dev/null | head -n 1)
    # Cross-platform stat compatibility
    if stat --version >/dev/null 2>&1; then
      # GNU stat (Linux)
      backup_age=$(stat -c %Y "$latest_backup" 2>/dev/null || echo "0")
    else
      # BSD stat (macOS)
      backup_age=$(stat -f %m "$latest_backup" 2>/dev/null || echo "0")
    fi
    current_time=$(date +%s)
    hours_old=$((($current_time - $backup_age) / 3600))

    echo -e "  Total backups: $backup_count"
    echo -e "  Latest backup: $(basename $latest_backup)"
    echo -e "  Backup age: ${hours_old}h ago"

    if [ $hours_old -gt 48 ]; then
      echo -e "  ${RED}⚠${NC} Warning: Latest backup is more than 48 hours old"
    else
      echo -e "  ${GREEN}✓${NC} Backups are current"
    fi
  else
    echo -e "  ${YELLOW}⚠${NC} No backups found"
  fi
else
  echo -e "  ${YELLOW}⚠${NC} Backup directory not found"
fi

# SSL Certificate Status
print_section "SSL Certificate Status"
if [ -f "traefik/acme/acme.json" ]; then
  cert_count=$(cat traefik/acme/acme.json 2>/dev/null | grep -o '"Domain"' | wc -l)
  echo -e "  Certificates: $cert_count domains"

  if [ -f ".env" ]; then
    source .env
    echo -e "\n  ${YELLOW}Certificate Expiry:${NC}"
    echo | openssl s_client -servername ${DOMAIN} -connect ${DOMAIN}:443 2>/dev/null | openssl x509 -noout -dates 2>/dev/null | grep "notAfter" | sed 's/notAfter=/  Expires: /' || echo "  Unable to check certificate"
  fi
else
  echo -e "  ${YELLOW}⚠${NC} No certificates found (may still be provisioning)"
fi

# Security Checks
print_section "Security Status"

# Check if .env is secure
if [ -f ".env" ]; then
  # Cross-platform stat compatibility
  if stat --version >/dev/null 2>&1; then
    # GNU stat (Linux)
    env_perms=$(stat -c %a .env)
  else
    # BSD stat (macOS)
    env_perms=$(stat -f %Lp .env)
  fi
  if [ "$env_perms" = "600" ]; then
    echo -e "  ${GREEN}✓${NC} .env file permissions: secure (600)"
  else
    echo -e "  ${RED}⚠${NC} .env file permissions: $env_perms (should be 600)"
  fi
else
  echo -e "  ${RED}✗${NC} .env file not found"
fi

# Check for default passwords
if [ -f ".env" ]; then
  if grep -q "change_this" .env 2>/dev/null; then
    echo -e "  ${RED}⚠${NC} Warning: Default passwords detected in .env"
  else
    echo -e "  ${GREEN}✓${NC} No default passwords in .env"
  fi
fi

# Summary
print_section "Summary"
echo ""

# Count healthy services
healthy_count=0
total_count=6
for service in traefik postgres redis litellm open-webui backup; do
  if docker-compose -f docker/docker-compose.yml --env-file .env ps -q $service &>/dev/null; then
    status=$(docker inspect --format='{{.State.Health.Status}}' $(docker-compose -f docker/docker-compose.yml --env-file .env ps -q $service) 2>/dev/null || echo "running")
    if [ "$status" = "healthy" ] || [ "$status" = "running" ]; then
      ((healthy_count++))
    fi
  fi
done

echo -e "Services: ${GREEN}$healthy_count${NC} / $total_count healthy"

if [ $healthy_count -eq $total_count ]; then
  echo -e "\n${GREEN}✓ All systems operational${NC}\n"
  exit 0
else
  echo -e "\n${YELLOW}⚠ Some services need attention${NC}\n"
  exit 1
fi
