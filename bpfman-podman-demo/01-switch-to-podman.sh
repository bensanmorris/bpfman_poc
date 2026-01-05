#!/bin/bash
# Remove Docker and install Podman for RHEL 9

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Switching to Podman ===${NC}"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then 
    echo -e "${RED}Please run as normal user (script will use sudo when needed)${NC}"
    exit 1
fi

# Check if Docker is installed
if command -v docker &> /dev/null; then
    echo "1. Docker detected. Removing..."
    
    # Stop Docker
    sudo systemctl stop docker 2>/dev/null || true
    sudo systemctl disable docker 2>/dev/null || true
    
    # Remove Docker packages
    sudo dnf remove -y docker-ce docker-ce-cli containerd.io \
        docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
    
    # Remove Docker repo
    sudo rm -f /etc/yum.repos.d/docker-ce.repo 2>/dev/null || true
    
    echo -e "${GREEN}✓ Docker removed${NC}"
else
    echo "1. Docker not installed, skipping removal"
fi
echo ""

# Check if Podman is already installed
if command -v podman &> /dev/null; then
    echo "2. Podman already installed"
    podman --version
else
    echo "2. Installing Podman..."
    sudo dnf install -y podman podman-docker
    echo -e "${GREEN}✓ Podman installed${NC}"
fi
echo ""

# Configure podman socket
echo "3. Configuring Podman socket (Docker API compatibility)..."
systemctl --user enable --now podman.socket 2>/dev/null || true

if systemctl --user is-active podman.socket &>/dev/null; then
    echo -e "${GREEN}✓ Podman socket active${NC}"
else
    echo -e "${YELLOW}⚠ Podman socket not active (not critical for this demo)${NC}"
fi
echo ""

# Verify
echo "4. Verifying Podman installation..."
podman --version
podman ps
echo -e "${GREEN}✓ Podman working${NC}"
echo ""

echo -e "${GREEN}=== Setup Complete! ===${NC}"
echo ""
echo "Podman is ready. Docker has been removed."
echo ""
echo "Next step:"
echo "  ${BLUE}./02-run-demo.sh${NC}"
