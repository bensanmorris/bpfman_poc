#!/bin/bash
# Clean up ALL XDP programs from all interfaces

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Clean Up All XDP Programs            ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Get all network interfaces
INTERFACES=$(ip link show | grep -E "^[0-9]+:" | awk -F': ' '{print $2}' | grep -v "^lo$")

echo "Checking all network interfaces for XDP programs..."
echo ""

for IFACE in $INTERFACES; do
    echo "Interface: $IFACE"
    
    # Check if XDP is attached
    if sudo bpftool net show dev $IFACE 2>/dev/null | grep -q "xdp:"; then
        echo -e "  ${YELLOW}⚠ XDP program found - removing...${NC}"
        
        # Try all removal methods
        sudo ip link set dev $IFACE xdp off 2>/dev/null || true
        sudo ip link set dev $IFACE xdpgeneric off 2>/dev/null || true
        sudo ip link set dev $IFACE xdpoffload off 2>/dev/null || true
        
        # Verify removal
        if sudo bpftool net show dev $IFACE 2>/dev/null | grep -q "xdp:"; then
            echo -e "  ${RED}✗ Still attached${NC}"
        else
            echo -e "  ${GREEN}✓ Removed${NC}"
        fi
    else
        echo -e "  ${GREEN}✓ No XDP program${NC}"
    fi
    echo ""
done

echo "Cleaning up pinned BPF objects..."
sudo rm -f /sys/fs/bpf/xdp_* 2>/dev/null || true
sudo rm -f /sys/fs/bpf/stats_map 2>/dev/null || true
echo -e "${GREEN}✓ Cleaned up pinned objects${NC}"
echo ""

echo "Current BPF programs:"
sudo bpftool prog show | grep -i xdp || echo "  (none)"
echo ""

echo "Current XDP attachments:"
sudo bpftool net show | grep -A 2 "xdp:" || echo "  (none)"
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Cleanup Complete! ✓             ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo "You can now load the packet counter:"
echo "  ./02-load.sh"
echo ""
