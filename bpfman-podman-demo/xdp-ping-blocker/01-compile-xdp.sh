#!/bin/bash
# Compile XDP program to eBPF bytecode

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Compile XDP Ping Blocker Program      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check for required tools
echo "1. Checking build requirements..."
MISSING=""

if ! command -v clang &> /dev/null; then
    MISSING="$MISSING clang"
fi

if ! command -v llc &> /dev/null; then
    MISSING="$MISSING llvm"
fi

if [ ! -z "$MISSING" ]; then
    echo -e "${RED}✗ Missing required tools:$MISSING${NC}"
    echo ""
    echo "Install on RHEL 9:"
    echo "  sudo dnf install -y clang llvm kernel-headers kernel-devel bpftool"
    exit 1
fi

echo -e "${GREEN}✓ Build tools available${NC}"
echo "  clang: $(clang --version | head -1)"
echo "  llvm: $(llc --version | head -1)"
echo ""

# Check kernel headers
echo "2. Checking kernel headers..."
KERNEL_VER=$(uname -r)
if [ -d "/lib/modules/$KERNEL_VER/build" ]; then
    echo -e "${GREEN}✓ Kernel headers found for $KERNEL_VER${NC}"
else
    echo -e "${YELLOW}⚠ Kernel headers not found${NC}"
    echo "Install: sudo dnf install -y kernel-devel-$KERNEL_VER"
fi
echo ""

# Compile the XDP program
echo "3. Compiling XDP program..."
clang -O2 -g \
    -target bpf \
    -D__TARGET_ARCH_x86 \
    -I/usr/include/bpf \
    -c xdp_block_ping.c \
    -o xdp_block_ping.o

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Compilation successful!${NC}"
else
    echo -e "${RED}✗ Compilation failed${NC}"
    exit 1
fi
echo ""

# Verify the output
echo "4. Verifying eBPF bytecode..."
if [ -f "xdp_block_ping.o" ]; then
    SIZE=$(stat -f%z "xdp_block_ping.o" 2>/dev/null || stat -c%s "xdp_block_ping.o" 2>/dev/null)
    echo -e "${GREEN}✓ Output file created: xdp_block_ping.o ($SIZE bytes)${NC}"
    
    # Show program info if bpftool is available
    if command -v bpftool &> /dev/null; then
        echo ""
        echo "Program sections:"
        bpftool prog show pinned xdp_block_ping.o 2>/dev/null || true
        echo ""
        echo "ELF sections:"
        llvm-objdump -h xdp_block_ping.o | grep -E "xdp|license" || echo "  (xdp section present)"
    fi
else
    echo -e "${RED}✗ Output file not created${NC}"
    exit 1
fi
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║        Compilation Complete! 🎉            ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "Output: xdp_block_ping.o"
echo ""
echo "Next steps:"
echo "  ./02-load-xdp-program.sh    # Load and attach the program"
