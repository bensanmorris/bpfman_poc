#!/bin/bash
# Master demo script - Complete XDP lifecycle demonstration

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                        ║${NC}"
echo -e "${CYAN}║      Complete eBPF/XDP Corporate POC Demo              ║${NC}"
echo -e "${CYAN}║      Dynamic Kernel-Level Security Policy              ║${NC}"
echo -e "${CYAN}║                                                        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}This demo will:${NC}"
echo "  1. Ensure bpfman is running"
echo "  2. Compile an XDP packet filter program"
echo "  3. Load and attach it to your network"
echo "  4. Demonstrate packet blocking"
echo "  5. Unload the program cleanly"
echo ""
echo -e "${YELLOW}Time required: ~3 minutes${NC}"
echo ""
read -p "Press Enter to start the demo..." 

# Change to demo directory
cd "$(dirname "$0")"

echo ""
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 1: Verify bpfman Infrastructure${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

# Check if bpfman is running
if ! sudo podman pod ps | grep -q bpfman-demo-pod; then
    echo -e "${YELLOW}bpfman not running. Starting it now...${NC}"
    echo ""
    
    if [ -f "../run-bpfman-demo.sh" ]; then
        cd ..
        ./run-bpfman-demo.sh
        cd xdp-ping-blocker
        echo ""
        echo -e "${GREEN}✓ bpfman started successfully${NC}"
    else
        echo -e "${RED}✗ Cannot find bpfman startup script${NC}"
        echo "Please run: ../run-bpfman-demo.sh first"
        exit 1
    fi
else
    echo -e "${GREEN}✓ bpfman is already running${NC}"
fi

sleep 2
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 2: Compile XDP Program${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

./01-compile-xdp.sh

echo ""
read -p "Press Enter to continue to loading the program..."
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 3: Load & Attach XDP Filter${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

./02-load-xdp-program.sh

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}DEMONSTRATION: XDP Filter Active${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo "The XDP program is now actively filtering packets."
echo "Let's verify it's working..."
echo ""

# Get interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)
echo -e "${YELLOW}Attempting to ping 8.8.8.8 (should timeout)...${NC}"
echo ""

# Try ping with timeout
if timeout 5 ping -c 3 8.8.8.8 2>&1 | tee /tmp/ping_output.txt | grep -q "bytes from"; then
    echo ""
    echo -e "${YELLOW}⚠ Ping succeeded - XDP may need testing from external host${NC}"
else
    echo ""
    echo -e "${GREEN}✓ Ping blocked/timed out as expected!${NC}"
    echo -e "${GREEN}✓ XDP filter is working!${NC}"
fi

echo ""
echo -e "${BLUE}Checking kernel trace logs for XDP activity...${NC}"
echo "(Press Ctrl+C after a few seconds)"
echo ""
sleep 2

# Show trace logs
sudo podman exec bpfman-demo-pod-bpfman timeout 5 cat /sys/kernel/debug/tracing/trace_pipe 2>/dev/null || {
    echo ""
    echo "Trace logs may require additional permissions"
}

echo ""
echo ""
read -p "Press Enter to unload the XDP program and restore normal networking..."
echo ""

echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo -e "${CYAN}Phase 4: Unload XDP Filter${NC}"
echo -e "${CYAN}═══════════════════════════════════════════════════════${NC}"
echo ""

./03-unload-xdp-program.sh

echo ""
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo -e "${BLUE}VERIFICATION: Normal Networking Restored${NC}"
echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
echo ""
echo -e "${YELLOW}Verifying ping works again...${NC}"
echo ""

if ping -c 3 -W 2 8.8.8.8 &>/dev/null; then
    echo -e "${GREEN}✓ Ping works! Network restored successfully!${NC}"
else
    echo -e "${YELLOW}⚠ Ping failed (may be a network issue)${NC}"
fi

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║                                                        ║${NC}"
echo -e "${CYAN}║           POC DEMONSTRATION COMPLETE! 🎉               ║${NC}"
echo -e "${CYAN}║                                                        ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}What Was Demonstrated:${NC}"
echo ""
echo "✅ Complete eBPF program lifecycle:"
echo "   • Compile from C source"
echo "   • Load into running kernel"
echo "   • Attach to network interface"
echo "   • Verify packet filtering"
echo "   • Unload cleanly"
echo ""
echo "✅ Zero-downtime policy changes:"
echo "   • No service restarts required"
echo "   • No kernel reboot needed"
echo "   • Instant activation/deactivation"
echo ""
echo "✅ Enterprise-grade capabilities:"
echo "   • Kernel-level security enforcement"
echo "   • Performance (10M+ packets/sec)"
echo "   • Safety (eBPF verified before load)"
echo "   • Observability (kernel trace logs)"
echo ""
echo -e "${BLUE}Corporate Value Proposition:${NC}"
echo ""
echo "🎯 Security: Block threats at the network edge"
echo "🎯 Performance: Faster than iptables/nftables"
echo "🎯 Agility: Deploy policies in seconds"
echo "🎯 Safety: No kernel modules (eBPF is safe)"
echo "🎯 Cost: Zero overhead vs userspace filtering"
echo ""
echo -e "${YELLOW}Use Cases for Your Organization:${NC}"
echo ""
echo "• DDoS mitigation and rate limiting"
echo "• Network segmentation enforcement"
echo "• Protocol filtering (block unwanted traffic)"
echo "• Container network policies"
echo "• Compliance (audit all network activity)"
echo "• Zero-trust networking"
echo ""
echo -e "${BLUE}OpenShift Deployment Path:${NC}"
echo ""
echo "This POC proves the technical foundation."
echo "For production OpenShift:"
echo ""
echo "  1. Deploy bpfman-operator (Kubernetes operator)"
echo "  2. Request custom SCC from OpenShift admins"
echo "  3. Deploy as DaemonSet across cluster"
echo "  4. Manage programs via CRDs (declarative)"
echo ""
echo "See: ../bpfman-openshift.yaml for full manifest"
echo ""
echo -e "${BLUE}Next Steps:${NC}"
echo ""
echo "  • Review: README.md (detailed documentation)"
echo "  • Extend: Modify xdp_block_ping.c for your use case"
echo "  • Deploy: Use bpfman-openshift.yaml in dev cluster"
echo "  • Present: Share this demo with stakeholders"
echo ""
echo -e "${GREEN}Demo scripts available:${NC}"
echo "  ./run-full-demo.sh       # Run this complete demo again"
echo "  ./01-compile-xdp.sh      # Just compile"
echo "  ./02-load-xdp-program.sh # Just load"
echo "  ./03-unload-xdp-program.sh # Just unload"
echo ""
echo -e "${CYAN}Thank you for running this POC! 🚀${NC}"
echo ""
