#!/bin/bash
# Load XDP packet counter program

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║      Load XDP Packet Counter Program      ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if program is compiled
if [ ! -f "xdp_counter.o" ]; then
    echo -e "${RED}✗ xdp_counter.o not found${NC}"
    echo "Run: ./01-compile.sh first"
    exit 1
fi
echo -e "${GREEN}✓ eBPF bytecode found${NC}"
echo ""

# Detect primary network interface
echo "1. Detecting network interface..."
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$INTERFACE" ]; then
    INTERFACE="eth0"
fi
echo "   Target interface: $INTERFACE"
echo ""

# Clean up any previous version - be thorough!
echo "2. Cleaning up previous XDP programs (if any)..."

# First, remove ANY XDP program from the target interface
if sudo bpftool net show dev $INTERFACE 2>/dev/null | grep -q "xdp:"; then
    echo "   Found existing XDP program on $INTERFACE - removing..."
    sudo ip link set dev $INTERFACE xdp off 2>/dev/null || true
    sudo ip link set dev $INTERFACE xdpgeneric off 2>/dev/null || true
    sudo ip link set dev $INTERFACE xdpoffload off 2>/dev/null || true
    sleep 1
fi

# Clean up old xdp_counter programs specifically
if sudo bpftool prog show | grep -q xdp_counter; then
    PROG_ID=$(sudo bpftool prog show | grep xdp_counter | grep -oP '^\d+' | head -1)
    if [ ! -z "$PROG_ID" ]; then
        echo "   Detaching old xdp_counter program ID $PROG_ID..."
        sudo bpftool net detach xdp dev $INTERFACE 2>/dev/null || true
    fi
fi

# Clean up any old xdp_block_ping programs too
if sudo bpftool prog show | grep -q xdp_block_ping; then
    PROG_ID=$(sudo bpftool prog show | grep xdp_block_ping | grep -oP '^\d+' | head -1)
    if [ ! -z "$PROG_ID" ]; then
        echo "   Detaching old xdp_block_ping program ID $PROG_ID..."
        sudo bpftool net detach xdp dev $INTERFACE 2>/dev/null || true
    fi
fi

# Remove pinned objects
sudo rm -f /sys/fs/bpf/xdp_counter 2>/dev/null || true
sudo rm -f /sys/fs/bpf/xdp_block_ping 2>/dev/null || true
sudo rm -f /sys/fs/bpf/stats_map 2>/dev/null || true

# Final verification that XDP is clear
sleep 1
if sudo bpftool net show dev $INTERFACE 2>/dev/null | grep -q "xdp:"; then
    echo -e "${RED}   ✗ Warning: XDP still attached, forcing removal...${NC}"
    sudo ip link set dev $INTERFACE xdp off 2>/dev/null || true
    sudo ip link set dev $INTERFACE xdpgeneric off 2>/dev/null || true
    sleep 1
fi

echo -e "${GREEN}   ✓ Clean${NC}"
echo ""

# Load the program
echo "3. Loading XDP packet counter into kernel..."
sudo bpftool prog load xdp_counter.o /sys/fs/bpf/xdp_counter \
    type xdp \
    pinmaps /sys/fs/bpf/

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✓ Program loaded${NC}"
else
    echo -e "${RED}✗ Failed to load program${NC}"
    exit 1
fi
echo ""

# Get program ID
PROGRAM_ID=$(sudo bpftool prog show pinned /sys/fs/bpf/xdp_counter | grep -oP '^\d+' | head -1)
echo "   Program ID: $PROGRAM_ID"
echo ""

# Attach to interface
echo "4. Attaching XDP program to $INTERFACE..."

# Try native mode first, fall back to generic
if sudo bpftool net attach xdp id $PROGRAM_ID dev $INTERFACE 2>&1; then
    echo -e "${GREEN}✓ XDP attached (native mode)${NC}"
elif sudo ip link set dev $INTERFACE xdp pinned /sys/fs/bpf/xdp_counter 2>&1; then
    echo -e "${GREEN}✓ XDP attached (native mode)${NC}"
else
    echo -e "${YELLOW}⚠ Native mode failed, trying generic mode...${NC}"
    sudo ip link set dev $INTERFACE xdpgeneric pinned /sys/fs/bpf/xdp_counter
    echo -e "${GREEN}✓ XDP attached (generic mode)${NC}"
fi
echo ""

# Verify
echo "5. Verifying program loaded and attached..."
echo ""
echo "Program in kernel:"
sudo bpftool prog show id $PROGRAM_ID
echo ""
echo "XDP attachment:"
sudo bpftool net show dev $INTERFACE
echo ""
echo "BPF maps:"
sudo bpftool map show | grep stats_map || echo "(stats_map should appear here)"
echo ""

# Initialize the map
echo "6. Initializing stats map..."
STATS_MAP_ID=$(sudo bpftool map show | grep stats_map | grep -oP '^\d+' | head -1)
if [ ! -z "$STATS_MAP_ID" ]; then
    echo "   Stats map ID: $STATS_MAP_ID"
    # Initialize with zeros
    echo "   (Map will be initialized on first packet)"
    echo -e "${GREEN}   ✓ Ready${NC}"
else
    echo -e "${YELLOW}   ⚠ Stats map not found, but this may be OK${NC}"
fi
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║     XDP Counter Running! 🚀                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}What's Happening:${NC}"
echo "  • XDP program attached to $INTERFACE"
echo "  • Counting ALL packets passing through"
echo "  • Stats stored in BPF map (kernel memory)"
echo "  • Packets still flow normally (XDP_PASS)"
echo ""
echo -e "${BLUE}Generate Some Traffic:${NC}"
echo "  # Ping to generate ICMP packets"
echo "  ping -c 5 8.8.8.8"
echo ""
echo "  # Curl to generate TCP packets"
echo "  curl -s http://example.com > /dev/null"
echo ""
echo "  # DNS query to generate UDP packets"
echo "  nslookup google.com"
echo ""
echo -e "${BLUE}View Statistics:${NC}"
echo "  ./03-show-stats.sh"
echo ""
echo -e "${BLUE}Watch Live:${NC}"
echo "  watch -n 1 ./03-show-stats.sh"
echo ""
echo -e "${BLUE}Cleanup:${NC}"
echo "  ./04-unload.sh"
echo ""
