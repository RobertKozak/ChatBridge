#!/bin/bash

# ChatBridge Uninstall Script
# Safely removes ChatBridge containers, volumes, and generated files

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

echo -e "${BLUE}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║       ChatBridge Uninstall Script                 ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if docker is available
if ! command -v docker &> /dev/null; then
    echo -e "${RED}Error: Docker is not installed or not in PATH${NC}"
    exit 1
fi

# Check if docker compose is available
if ! docker compose version &> /dev/null; then
    echo -e "${RED}Error: Docker Compose is not available${NC}"
    exit 1
fi

# Check if ChatBridge containers exist
echo -e "${BLUE}Checking for ChatBridge containers...${NC}"
CHATBRIDGE_CONTAINERS=$(docker ps -a --filter "name=chatbridge" --format "{{.Names}}" 2>/dev/null || true)

if [ -z "$CHATBRIDGE_CONTAINERS" ]; then
    echo -e "${YELLOW}No ChatBridge containers found.${NC}"
else
    echo -e "${GREEN}Found ChatBridge containers:${NC}"
    echo "$CHATBRIDGE_CONTAINERS" | while read container; do
        echo -e "  - ${container}"
    done
fi

echo ""
echo -e "${YELLOW}What would you like to remove?${NC}"
echo ""
echo "1) Containers and volumes only (keep config files)"
echo "2) Everything except .env (remove containers, volumes, credentials, certs, backups)"
echo "3) Complete uninstall (remove everything including .env)"
echo "4) Cancel"
echo ""
read -p "Enter your choice [1-4]: " choice

case $choice in
    1)
        echo ""
        echo -e "${BLUE}Removing containers and volumes...${NC}"
        cd "$SCRIPT_DIR/docker" || exit 1
        docker compose down -v 2>&1 | grep -v "variable is not set" || true
        echo -e "${GREEN}✓ Containers and volumes removed${NC}"
        echo ""
        echo -e "${GREEN}Preserved:${NC}"
        echo -e "  - .env file"
        echo -e "  - Cloudflare credentials"
        echo -e "  - Traefik certificates"
        echo -e "  - Backup files"
        ;;

    2)
        echo ""
        echo -e "${BLUE}Removing containers, volumes, and generated files...${NC}"

        # Remove containers and volumes
        cd "$SCRIPT_DIR/docker" || exit 1
        docker compose down -v 2>&1 | grep -v "variable is not set" || true
        echo -e "${GREEN}✓ Containers and volumes removed${NC}"

        # Remove generated files
        cd "$SCRIPT_DIR" || exit 1

        if [ -f "docker/cloudflared/credentials.json" ]; then
            rm -f docker/cloudflared/credentials.json
            echo -e "${GREEN}✓ Cloudflare credentials removed${NC}"
        fi

        if [ -f "docker/traefik/acme/acme.json" ]; then
            rm -f docker/traefik/acme/acme.json
            echo -e "${GREEN}✓ Traefik certificates removed${NC}"
        fi

        if [ -d "backups" ]; then
            rm -rf backups
            echo -e "${GREEN}✓ Backup files removed${NC}"
        fi

        echo ""
        echo -e "${GREEN}Preserved:${NC}"
        echo -e "  - .env file (API keys and passwords)"
        ;;

    3)
        echo ""
        echo -e "${RED}WARNING: This will remove EVERYTHING, including your .env file with API keys!${NC}"
        read -p "Are you sure? Type 'yes' to confirm: " confirm

        if [ "$confirm" != "yes" ]; then
            echo -e "${YELLOW}Cancelled.${NC}"
            exit 0
        fi

        echo ""
        echo -e "${BLUE}Removing everything...${NC}"

        # Remove containers and volumes
        cd "$SCRIPT_DIR/docker" || exit 1
        docker compose down -v 2>&1 | grep -v "variable is not set" || true
        echo -e "${GREEN}✓ Containers and volumes removed${NC}"

        # Remove all generated files
        cd "$SCRIPT_DIR" || exit 1

        if [ -f ".env" ]; then
            rm -f .env
            echo -e "${GREEN}✓ .env file removed${NC}"
        fi

        if [ -f "docker/cloudflared/credentials.json" ]; then
            rm -f docker/cloudflared/credentials.json
            echo -e "${GREEN}✓ Cloudflare credentials removed${NC}"
        fi

        if [ -f "docker/traefik/acme/acme.json" ]; then
            rm -f docker/traefik/acme/acme.json
            echo -e "${GREEN}✓ Traefik certificates removed${NC}"
        fi

        if [ -d "backups" ]; then
            rm -rf backups
            echo -e "${GREEN}✓ Backup files removed${NC}"
        fi

        echo ""
        echo -e "${GREEN}Complete uninstall finished.${NC}"
        ;;

    4)
        echo -e "${YELLOW}Cancelled.${NC}"
        exit 0
        ;;

    *)
        echo -e "${RED}Invalid choice.${NC}"
        exit 1
        ;;
esac

echo ""
echo -e "${BLUE}Verifying cleanup...${NC}"

# Check for remaining containers
REMAINING=$(docker ps -a --filter "name=chatbridge" --format "{{.Names}}" 2>/dev/null || true)
if [ -z "$REMAINING" ]; then
    echo -e "${GREEN}✓ No ChatBridge containers found${NC}"
else
    echo -e "${YELLOW}Warning: Some containers still exist:${NC}"
    echo "$REMAINING"
fi

# Check for remaining volumes
REMAINING_VOLUMES=$(docker volume ls --filter "name=docker_" --format "{{.Name}}" 2>/dev/null || true)
if [ -z "$REMAINING_VOLUMES" ]; then
    echo -e "${GREEN}✓ No ChatBridge volumes found${NC}"
else
    echo -e "${YELLOW}Warning: Some volumes still exist:${NC}"
    echo "$REMAINING_VOLUMES"
fi

echo ""
echo -e "${GREEN}╔════════════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║   ChatBridge Uninstall Complete!                  ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}To reinstall:${NC}"
echo -e "  1. cp .env.example .env  ${YELLOW}(if you removed .env)${NC}"
echo -e "  2. Edit .env with your settings"
echo -e "  3. Copy Cloudflare credentials ${YELLOW}(if removed)${NC}"
echo -e "  4. cd docker && docker compose up -d"
echo ""
