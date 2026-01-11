#!/bin/bash
# Unload XDP packet counter program

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     Unload XDP Packet Counter Program     ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Detect interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$INTERFACE" ]; then
    INTERFACE="eth0"
fi

echo "1. Finding XDP program on $INTERFACE..."
if sudo bpftool net show dev $INTERFACE 2>/dev/null | grep -q xdp; then
    echo -e "${GREEN}✓ XDP program found${NC}"
else
    echo -e "${YELLOW}⚠ No XDP program attached${NC}"
fi
echo ""

# Show final statistics before unloading
echo "2. Final statistics:"
echo ""
if [ -f "./03-show-stats-python.py" ]; then
    python3 ./03-show-stats-python.py 2>/dev/null || echo "   (Could not read final stats)"
elif [ -f "./03-show-stats.sh" ]; then
    bash ./03-show-stats.sh 2>/dev/null || echo "   (Could not read final stats)"
fi
echo ""

# Detach from interface
echo "3. Detaching XDP program from $INTERFACE..."
if sudo bpftool prog show | grep -q xdp_counter; then
    PROG_ID=$(sudo bpftool prog show | grep xdp_counter | grep -oP '^\d+' | head -1)
    if [ ! -z "$PROG_ID" ]; then
        sudo bpftool net detach xdp dev $INTERFACE 2>/dev/null || true
    fi
fi
sudo ip link set dev $INTERFACE xdp off 2>/dev/null || true
sudo ip link set dev $INTERFACE xdpgeneric off 2>/dev/null || true
echo -e "${GREEN}✓ Detached${NC}"
echo ""

# Unpin and remove
echo "4. Removing BPF objects..."
sudo rm -f /sys/fs/bpf/xdp_counter 2>/dev/null || true
sudo rm -f /sys/fs/bpf/stats_map 2>/dev/null || true
echo -e "${GREEN}✓ Cleaned up${NC}"
echo ""

# Verify
echo "5. Verifying cleanup..."
if sudo bpftool prog show | grep -q xdp_counter; then
    echo -e "${YELLOW}⚠ Program still in kernel${NC}"
else
    echo -e "${GREEN}✓ Program removed${NC}"
fi

if sudo bpftool net show dev $INTERFACE 2>/dev/null | grep -q xdp; then
    echo -e "${YELLOW}⚠ XDP still attached${NC}"
else
    echo -e "${GREEN}✓ XDP detached${NC}"
fi

if sudo bpftool map show | grep -q stats_map; then
    echo -e "${YELLOW}⚠ stats_map still exists${NC}"
else
    echo -e "${GREEN}✓ Maps removed${NC}"
fi
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║         Cleanup Complete! ✓                ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "To run again:"
echo "  ./02-load.sh"
echo ""
