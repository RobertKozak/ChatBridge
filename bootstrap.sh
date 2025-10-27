#!/bin/bash
# ChatBridge Bootstrap Installer
# Downloads and extracts the latest release, then runs the installer

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# GitHub repository
REPO="RobertKozak/ChatBridge"

# Detect OS and set appropriate default installation directory
if [ -z "$INSTALL_DIR" ]; then
  if [[ "$OSTYPE" == "darwin"* ]]; then
    # macOS - use user's home directory by default
    INSTALL_DIR="$HOME/chatbridge"
  else
    # Linux - use /opt if we have permission, otherwise use home directory
    if [ -w "/opt" ] || [ "$EUID" -eq 0 ]; then
      INSTALL_DIR="/opt/chatbridge"
    else
      INSTALL_DIR="$HOME/chatbridge"
    fi
  fi
fi

# Print functions
print_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Check if running as root
if [ "$EUID" -eq 0 ]; then
  print_warning "Running as root. Consider creating a non-root user for Docker."
fi

# Check prerequisites
print_info "Checking prerequisites..."

if ! command -v curl &> /dev/null; then
  print_error "curl is required but not installed."
  echo "Install it with: sudo apt-get install curl (Ubuntu/Debian) or brew install curl (macOS)"
  exit 1
fi

if ! command -v tar &> /dev/null; then
  print_error "tar is required but not installed."
  exit 1
fi

# Get latest release info
print_info "Fetching latest release information from GitHub..."

LATEST_RELEASE=$(curl -s "https://api.github.com/repos/${REPO}/releases/latest")

if echo "$LATEST_RELEASE" | grep -q "API rate limit exceeded"; then
  print_error "GitHub API rate limit exceeded. Please try again later."
  exit 1
fi

TAG_NAME=$(echo "$LATEST_RELEASE" | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
DOWNLOAD_URL=$(echo "$LATEST_RELEASE" | grep "browser_download_url.*tar.gz\"" | grep -v ".sha256" | sed -E 's/.*"([^"]+)".*/\1/')

if [ -z "$TAG_NAME" ] || [ -z "$DOWNLOAD_URL" ]; then
  print_error "Failed to fetch release information. Please check your internet connection."
  print_info "You can manually download from: https://github.com/${REPO}/releases/latest"
  exit 1
fi

print_success "Found latest release: ${TAG_NAME}"

# Create installation directory
print_info "Creating installation directory: ${INSTALL_DIR}"

if [ -d "$INSTALL_DIR" ]; then
  print_warning "Directory $INSTALL_DIR already exists."
  read -p "Do you want to overwrite it? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    print_info "Installation cancelled."
    exit 0
  fi
  rm -rf "$INSTALL_DIR"
fi

# Try to create the directory
if ! mkdir -p "$INSTALL_DIR" 2>/dev/null; then
  print_error "Cannot create directory: ${INSTALL_DIR}"
  echo ""
  echo "You can either:"
  echo "  1. Run with sudo: curl -fsSL https://raw.githubusercontent.com/${REPO}/main/bootstrap.sh | sudo bash"
  echo "  2. Specify a different directory: INSTALL_DIR=~/chatbridge curl -fsSL https://raw.githubusercontent.com/${REPO}/main/bootstrap.sh | bash"
  echo "  3. Create the directory manually with appropriate permissions"
  exit 1
fi

cd "$INSTALL_DIR"

# Download release
print_info "Downloading ChatBridge ${TAG_NAME}..."
TEMP_FILE="/tmp/chatbridge-${TAG_NAME}.tar.gz"

if ! curl -L -f -o "$TEMP_FILE" "$DOWNLOAD_URL"; then
  print_error "Failed to download release."
  exit 1
fi

print_success "Download complete"

# Verify download (optional - download checksum and verify)
CHECKSUM_URL=$(echo "$LATEST_RELEASE" | grep "browser_download_url.*sha256\"" | sed -E 's/.*"([^"]+)".*/\1/')
if [ -n "$CHECKSUM_URL" ]; then
  print_info "Verifying checksum..."
  curl -L -s -o "/tmp/chatbridge.sha256" "$CHECKSUM_URL"

  cd /tmp
  if sha256sum -c chatbridge.sha256 2>/dev/null; then
    print_success "Checksum verification passed"
  else
    print_warning "Checksum verification failed, but continuing..."
  fi
  cd "$INSTALL_DIR"
fi

# Extract archive
print_info "Extracting archive..."
if ! tar -xzf "$TEMP_FILE" --strip-components=1; then
  print_error "Failed to extract archive."
  rm -f "$TEMP_FILE"
  exit 1
fi

rm -f "$TEMP_FILE"
print_success "Extraction complete"

# Verify installation
print_info "Verifying installation..."
if [ -f "./verify-installation.sh" ]; then
  chmod +x ./verify-installation.sh
  if ! ./verify-installation.sh; then
    print_error "Installation verification failed."
    exit 1
  fi
else
  # Manual verification
  if [ -f "./install.sh" ] && [ -f "./docker/docker-compose.yml" ]; then
    print_success "Installation files verified"
  else
    print_error "Installation appears incomplete."
    exit 1
  fi
fi

# Display next steps
echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  ChatBridge Bootstrap Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Installation directory: ${INSTALL_DIR}"
echo ""
echo "Next steps:"
echo "  1. cd ${INSTALL_DIR}"
echo "  2. ./install.sh"
echo "  3. Follow the prompts to configure your domain and API keys"
echo ""
echo "Documentation:"
echo "  - Quick Start: cat docs/QUICKSTART.md"
echo "  - Full README: cat README.md"
echo "  - VPS Setup: cat docs/VPS_SETUP.md"
echo ""
echo -e "${BLUE}For support, visit: https://github.com/${REPO}/issues${NC}"
echo ""

# Ask if user wants to start installation now
read -p "Would you like to start the installation now? (Y/n): " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]] || [[ -z $REPLY ]]; then
  print_info "Starting installation..."
  exec ./install.sh
else
  print_info "You can start the installation later by running:"
  echo "  cd ${INSTALL_DIR} && ./install.sh"
fi
