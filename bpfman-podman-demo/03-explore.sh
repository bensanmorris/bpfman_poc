#!/bin/bash
# Interactive exploration of bpfman

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== bpfman Exploration Guide ===${NC}"
echo ""

# Check if pod is running
if ! podman pod exists bpfman-demo-pod 2>/dev/null; then
    echo -e "${YELLOW}Pod not running. Run ./02-run-demo.sh first${NC}"
    exit 1
fi

CONTAINER="bpfman-demo-pod-bpfman"

show_section() {
    echo ""
    echo -e "${BLUE}▶ $1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

show_section "Current eBPF Programs"
podman exec $CONTAINER bpfmanctl list
echo ""
read -p "Press Enter to continue..."

show_section "Detailed Program Information"
podman exec $CONTAINER bpfmanctl list -v
echo ""
read -p "Press Enter to continue..."

show_section "BPF Filesystem"
echo "Contents of /sys/fs/bpf:"
podman exec $CONTAINER ls -laR /sys/fs/bpf/ | head -n 30
echo ""
read -p "Press Enter to continue..."

show_section "Container Environment"
echo "Environment variables:"
podman exec $CONTAINER env | grep -E "RUST|PATH|HOME"
echo ""
echo "Kernel version:"
podman exec $CONTAINER uname -r
echo ""
echo "Available network interfaces:"
podman exec $CONTAINER ip link show | head -n 20
echo ""
read -p "Press Enter to continue..."

show_section "bpfman Logs"
echo "Last 30 lines:"
podman logs $CONTAINER --tail=30
echo ""
read -p "Press Enter to continue..."

show_section "Interactive Commands"
echo ""
echo "Try these commands:"
echo ""
echo "1. List all programs:"
echo "   ${GREEN}podman exec $CONTAINER bpfmanctl list${NC}"
echo ""
echo "2. Get program details:"
echo "   ${GREEN}podman exec $CONTAINER bpfmanctl get <program-id>${NC}"
echo ""
echo "3. Load another program:"
echo "   ${GREEN}podman exec $CONTAINER bpfmanctl load-from-image \\${NC}"
echo "   ${GREEN}     --image-url quay.io/bpfman-bytecode/xdp_pass:latest${NC}"
echo ""
echo "4. Unload a program:"
echo "   ${GREEN}podman exec $CONTAINER bpfmanctl unload <program-id>${NC}"
echo ""
echo "5. Shell into container:"
echo "   ${GREEN}podman exec -it $CONTAINER /bin/sh${NC}"
echo ""
echo "6. View live logs:"
echo "   ${GREEN}podman logs -f $CONTAINER${NC}"
echo ""
echo "7. Inspect pod:"
echo "   ${GREEN}podman pod inspect bpfman-demo-pod${NC}"
echo ""

show_section "OpenShift Requirements Summary"
echo ""
echo "This demo shows what OpenShift needs:"
echo ""
echo "Security Context Constraints (SCC):"
echo "  • ${YELLOW}allowPrivilegedContainer: true${NC}"
echo "  • ${YELLOW}allowHostNetwork: true${NC}"
echo "  • ${YELLOW}allowHostPID: true${NC}"
echo "  • ${YELLOW}allowHostDirVolumePlugin: true${NC}"
echo ""
echo "Required Capabilities:"
echo "  • ${YELLOW}BPF${NC} - Load eBPF programs"
echo "  • ${YELLOW}NET_ADMIN${NC} - Attach to network interfaces"
echo "  • ${YELLOW}SYS_ADMIN${NC} - Legacy eBPF operations"
echo "  • ${YELLOW}SYS_RESOURCE${NC} - Resource limits"
echo ""
echo "Host Paths:"
echo "  • ${YELLOW}/sys/fs/bpf${NC} - BPF filesystem (read/write)"
echo "  • ${YELLOW}/sys/kernel/debug${NC} - Debug info (read-only)"
echo "  • ${YELLOW}/lib/modules${NC} - Kernel modules (read-only)"
echo ""
echo "See bpfman-openshift.yaml for complete OpenShift manifest"
echo ""
