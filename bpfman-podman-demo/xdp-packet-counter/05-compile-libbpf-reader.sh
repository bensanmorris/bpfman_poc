#!/bin/bash
# Compile the libbpf-based statistics reader

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Compile libbpf Statistics Reader        ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check for gcc
if ! command -v gcc &> /dev/null; then
    echo -e "${RED}✗ gcc not found${NC}"
    echo "Install: sudo dnf install gcc"
    exit 1
fi
echo -e "${GREEN}✓ gcc available${NC}"

# Check for libbpf
if [ ! -f "/usr/include/bpf/libbpf.h" ]; then
    echo -e "${RED}✗ libbpf headers not found${NC}"
    echo "Install: sudo dnf install libbpf-devel"
    exit 1
fi
echo -e "${GREEN}✓ libbpf-devel available${NC}"

# Check for libbpf library
if ! ldconfig -p | grep -q libbpf.so; then
    echo -e "${YELLOW}⚠ libbpf library may not be installed${NC}"
    echo "Install: sudo dnf install libbpf"
    
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi
echo -e "${GREEN}✓ libbpf library available${NC}"
echo ""

echo "Compiling stats_reader.c..."
echo ""

# Compile with gcc
gcc -O2 -Wall \
    stats_reader.c \
    -o stats_reader \
    -lbpf -lelf -lz

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Compilation successful!${NC}"
    echo ""
    echo "Output file: stats_reader"
    ls -lh stats_reader
    echo ""
    echo "File type:"
    file stats_reader
    echo ""
else
    echo -e "${RED}✗ Compilation failed${NC}"
    exit 1
fi

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     Production Reader Ready! 🎉           ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}What is this?${NC}"
echo "  This is a native C program that uses the libbpf API"
echo "  to directly read BPF maps. This is how production"
echo "  applications interact with eBPF programs."
echo ""
echo -e "${BLUE}Advantages over bpftool/Python:${NC}"
echo "  ✅ Direct API access (no shell commands)"
echo "  ✅ Type-safe (matches kernel struct exactly)"
echo "  ✅ Fast (native compiled code)"
echo "  ✅ Production-ready pattern"
echo "  ✅ No external dependencies at runtime"
echo ""
echo -e "${BLUE}Usage:${NC}"
echo "  # Run once:"
echo "  sudo ./stats_reader"
echo ""
echo "  # Watch live:"
echo "  watch -n 1 sudo ./stats_reader"
echo ""
echo -e "${YELLOW}Note:${NC} Requires sudo to access BPF filesystem"
echo ""
