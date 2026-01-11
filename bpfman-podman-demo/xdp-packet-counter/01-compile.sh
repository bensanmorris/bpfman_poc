#!/bin/bash
# Compile XDP packet counter program

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║    Compile XDP Packet Counter Program     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check for clang
if ! command -v clang &> /dev/null; then
    echo -e "${RED}✗ clang not found${NC}"
    echo "Install: sudo dnf install clang"
    exit 1
fi
echo -e "${GREEN}✓ clang available${NC}"

# Check for kernel headers
if [ ! -d "/usr/include/linux" ]; then
    echo -e "${RED}✗ Linux headers not found${NC}"
    echo "Install: sudo dnf install kernel-headers"
    exit 1
fi
echo -e "${GREEN}✓ Kernel headers available${NC}"

# Check for libbpf headers
if [ ! -f "/usr/include/bpf/bpf_helpers.h" ]; then
    echo -e "${YELLOW}⚠ libbpf-devel headers not found${NC}"
    echo "Install: sudo dnf install libbpf-devel"
    
    read -p "Install now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        sudo dnf install -y libbpf-devel
    else
        exit 1
    fi
fi
echo -e "${GREEN}✓ libbpf headers available${NC}"
echo ""

echo "Compiling XDP packet counter..."
echo ""

# Compile with clang
clang -O2 -g \
    -target bpf \
    -D__TARGET_ARCH_x86 \
    -I/usr/include/x86_64-linux-gnu \
    -c xdp_counter.c \
    -o xdp_counter.o

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Compilation successful!${NC}"
    echo ""
    echo "Output file: xdp_counter.o"
    ls -lh xdp_counter.o
    echo ""
    echo "File type:"
    file xdp_counter.o
    echo ""
else
    echo -e "${RED}✗ Compilation failed${NC}"
    exit 1
fi

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Ready to Load! 🎉                     ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Next step:"
echo "  ./02-load.sh"
echo ""
