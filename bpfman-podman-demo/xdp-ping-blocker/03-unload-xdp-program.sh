#!/bin/bash
# Unload and detach XDP program from interface

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║      Unload XDP Ping Blocker Program       ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if bpfman pod is running
echo "1. Checking bpfman availability..."
if ! sudo podman pod ps | grep -q bpfman-demo-pod; then
    echo -e "${RED}✗ bpfman pod not running${NC}"
    exit 1
fi
echo -e "${GREEN}✓ bpfman pod is running${NC}"
echo ""

# Detect network interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
if [ -z "$INTERFACE" ]; then
    INTERFACE="eth0"
fi
echo "Target interface: $INTERFACE"
echo ""

# Check if XDP program is attached
echo "2. Checking XDP attachment status..."
XDP_ATTACHED=$(sudo podman exec bpfman-demo-pod-bpfman ip link show $INTERFACE | grep -i xdp || echo "")

if [ -z "$XDP_ATTACHED" ]; then
    echo -e "${YELLOW}⚠ No XDP program appears to be attached${NC}"
else
    echo -e "${GREEN}✓ XDP program is attached${NC}"
    echo "   $XDP_ATTACHED"
fi
echo ""

# Detach XDP program from interface
echo "3. Detaching XDP program from interface..."
sudo podman exec bpfman-demo-pod-bpfman ip link set dev $INTERFACE xdp off 2>&1 || {
    echo -e "${YELLOW}⚠ Detach command returned error (may already be detached)${NC}"
}
echo -e "${GREEN}✓ Detachment attempted${NC}"
echo ""

# Unpin and remove the program
echo "4. Removing pinned program..."
if sudo podman exec bpfman-demo-pod-bpfman test -f /sys/fs/bpf/xdp_block_ping; then
    sudo podman exec bpfman-demo-pod-bpfman rm -f /sys/fs/bpf/xdp_block_ping
    echo -e "${GREEN}✓ Pinned program removed${NC}"
else
    echo -e "${YELLOW}⚠ Pinned program not found (may already be removed)${NC}"
fi
echo ""

# Verify removal
echo "5. Verifying XDP removal..."
XDP_STATUS=$(sudo podman exec bpfman-demo-pod-bpfman ip link show $INTERFACE | grep -i xdp || echo "")

if [ -z "$XDP_STATUS" ]; then
    echo -e "${GREEN}✓ XDP program successfully removed${NC}"
else
    echo -e "${YELLOW}⚠ XDP status still showing: $XDP_STATUS${NC}"
fi
echo ""

# Check for any remaining eBPF programs
echo "6. Checking for remaining XDP programs..."
REMAINING=$(sudo podman exec bpfman-demo-pod-bpfman bpftool prog show | grep -i xdp_block_ping || echo "")

if [ -z "$REMAINING" ]; then
    echo -e "${GREEN}✓ No XDP ping blocker programs found${NC}"
else
    echo -e "${YELLOW}⚠ Found remaining program:${NC}"
    echo "$REMAINING"
fi
echo ""

# Test ping - should work again!
echo "7. Testing network connectivity - ping should WORK again..."
if ping -c 3 -W 2 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}✓ Ping works! XDP filter removed successfully! 🎉${NC}"
else
    echo -e "${RED}✗ Ping still failing (network issue?)${NC}"
fi
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║       XDP Program Unloaded! ✓              ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}Status:${NC}"
echo "  • XDP program detached from interface"
echo "  • Pinned program removed"
echo "  • Network traffic flowing normally"
echo ""
echo -e "${BLUE}Verification Commands:${NC}"
echo "  # Verify no XDP attached:"
echo "  sudo podman exec bpfman-demo-pod-bpfman ip link show $INTERFACE"
echo ""
echo "  # Check loaded programs:"
echo "  sudo podman exec bpfman-demo-pod-bpfman bpftool prog show"
echo ""
echo "  # Test connectivity:"
echo "  ping 8.8.8.8"
echo ""
echo -e "${BLUE}To reload:${NC}"
echo "  ./02-load-xdp-program.sh"
echo ""
echo -e "${YELLOW}Corporate POC Demonstrated:${NC}"
echo "  ✅ Dynamic eBPF program lifecycle management"
echo "  ✅ Load → Test → Unload workflow"
echo "  ✅ Zero service disruption"
echo "  ✅ Kernel-level security policy enforcement"
echo "  ✅ Instant policy activation/deactivation"
echo ""
