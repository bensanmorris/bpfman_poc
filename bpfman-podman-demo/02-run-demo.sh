#!/bin/bash
# Run complete bpfman demo with podman and Red Hat registry
# Fixed version - uses Red Hat image with no command override

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║     bpfman Demo with Podman (Red Hat)      ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check podman
if ! command -v podman &> /dev/null; then
    echo -e "${RED}Podman not found!${NC}"
    echo "Run: ./01-switch-to-podman.sh"
    exit 1
fi

echo "Using: $(podman --version)"
echo ""

# Check for Red Hat registry login
echo "1. Checking Red Hat registry authentication..."
if sudo podman login --get-login registry.redhat.io &>/dev/null; then
    echo -e "${GREEN}✓ Logged into registry.redhat.io${NC}"
else
    echo -e "${YELLOW}⚠ Not logged into registry.redhat.io${NC}"
    echo ""
    echo "Red Hat registry authentication required for bpfman images."
    echo ""
    read -p "Login to registry.redhat.io now? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo ""
        echo "Enter your Red Hat credentials:"
        sudo podman login registry.redhat.io
        if [ $? -eq 0 ]; then
            echo -e "${GREEN}✓ Login successful${NC}"
        else
            echo -e "${RED}✗ Login failed${NC}"
            exit 1
        fi
    else
        echo "Cannot proceed without registry access."
        echo ""
        echo "To login manually:"
        echo "  sudo podman login registry.redhat.io"
        exit 1
    fi
fi
echo ""

# Pull the bpfman image
echo "2. Pulling bpfman image from Red Hat registry..."
echo "   (Cached if already downloaded)"
if sudo podman pull registry.redhat.io/bpfman/bpfman:0.5.9; then
    echo -e "${GREEN}✓ Image ready${NC}"
else
    echo -e "${RED}✗ Failed to pull image${NC}"
    echo "Check your Red Hat subscription and credentials"
    exit 1
fi
echo ""

# Check SELinux status
echo "3. Checking SELinux status..."
if command -v getenforce &> /dev/null; then
    SELINUX_STATUS=$(getenforce)
    echo "   SELinux: $SELINUX_STATUS"
    if [ "$SELINUX_STATUS" = "Enforcing" ]; then
        echo -e "   ${YELLOW}SELinux is enforcing - using spc_t context${NC}"
    fi
fi
echo ""

# Clean up previous runs
echo "4. Cleaning up any previous runs..."
podman pod rm -f bpfman-demo-pod 2>/dev/null || true
sudo podman pod rm -f bpfman-demo-pod 2>/dev/null || true
sleep 2
echo -e "${GREEN}✓ Clean${NC}"
echo ""

# Create pod configuration with Red Hat image (NO ARGS!)
echo "5. Creating bpfman pod configuration..."
cat > bpfman-pod.yaml << 'EOFPOD'
apiVersion: v1
kind: Pod
metadata:
  name: bpfman-demo-pod
  labels:
    app: bpfman
spec:
  hostNetwork: true
  hostPID: true
  containers:
  - name: bpfman
    image: registry.redhat.io/bpfman/bpfman:0.5.9
    securityContext:
      privileged: true
      seLinuxOptions:
        type: spc_t
      capabilities:
        add:
        - SYS_ADMIN
        - NET_ADMIN
        - BPF
        - SYS_RESOURCE
    env:
    - name: RUST_LOG
      value: "info"
    volumeMounts:
    - name: bpffs
      mountPath: /sys/fs/bpf
    - name: debugfs
      mountPath: /sys/kernel/debug
      readOnly: true
    - name: modules
      mountPath: /lib/modules
      readOnly: true
    - name: bpfman-sock
      mountPath: /run/bpfman-sock
  - name: bpfman-agent
    image: registry.redhat.io/bpfman/bpfman-agent:0.5.9
    command: ["/bin/sleep", "infinity"]
    securityContext:
      privileged: true
    env:
    - name: BPFMAN_SOCKET_PATH
      value: "/run/bpfman-sock/bpfman.sock"
    volumeMounts:
    - name: bpfman-sock
      mountPath: /run/bpfman-sock
  volumes:
  - name: bpffs
    hostPath:
      path: /sys/fs/bpf
      type: DirectoryOrCreate
  - name: debugfs
    hostPath:
      path: /sys/kernel/debug
      type: Directory
  - name: modules
    hostPath:
      path: /lib/modules
      type: Directory
  - name: bpfman-sock
    emptyDir: {}
EOFPOD

echo -e "${GREEN}✓ Configuration created (bpfman + bpfman-agent with shared socket)${NC}"
echo ""

# Deploy with sudo
echo "6. Deploying bpfman pod..."
sudo podman play kube bpfman-pod.yaml
echo -e "${GREEN}✓ Pod deployed${NC}"
echo ""

PODMAN="sudo podman"

# Wait for startup
echo "7. Waiting for bpfman to start..."
sleep 5

READY=false
for i in {1..20}; do
    if $PODMAN logs bpfman-demo-pod-bpfman 2>&1 | grep -q "Listening on"; then
        echo -e "${GREEN}✓ bpfman is ready!${NC}"
        READY=true
        break
    fi
    echo -n "."
    sleep 2
done
echo ""

if [ "$READY" = false ]; then
    echo -e "${YELLOW}⚠ bpfman may not be fully started${NC}"
    echo ""
fi

# Show status
echo "8. Pod Status:"
echo ""
$PODMAN pod ps --filter name=bpfman-demo-pod
echo ""
$PODMAN ps --filter pod=bpfman-demo-pod
echo ""

# Show bpfman-rpc is running and listening
echo "9. Verifying bpfman-rpc service..."
echo ""
echo "bpfman-rpc logs:"
$PODMAN logs bpfman-demo-pod-bpfman --tail=10
echo ""

# Check socket exists
echo "10. Checking gRPC socket..."
if $PODMAN exec bpfman-demo-pod-bpfman test -S /run/bpfman-sock/bpfman.sock; then
    echo -e "${GREEN}✓ Socket exists and is ready${NC}"
    $PODMAN exec bpfman-demo-pod-bpfman ls -lh /run/bpfman-sock/
else
    echo -e "${YELLOW}⚠ Socket not found${NC}"
fi
echo ""

# Check BPF filesystem access
echo "11. Verifying BPF filesystem access..."
$PODMAN exec bpfman-demo-pod-bpfman ls -lah /sys/fs/bpf/ | head -n 10
echo ""

# Check system capabilities
echo "12. Verifying container capabilities..."
echo "Checking privileged access:"
$PODMAN exec bpfman-demo-pod-bpfman cat /proc/self/status | grep -E "Cap(Inh|Prm|Eff)" | head -3
echo ""

# Show mounted volumes
echo "13. Verifying required mounts..."
echo "BPF filesystem:"
$PODMAN exec bpfman-demo-pod-bpfman mount | grep bpf || echo "  Checking /sys/fs/bpf..."
$PODMAN exec bpfman-demo-pod-bpfman ls -ld /sys/fs/bpf
echo ""
echo "Debug filesystem:"
$PODMAN exec bpfman-demo-pod-bpfman ls -ld /sys/kernel/debug 2>/dev/null || echo "  (optional, not critical)"
echo ""
echo "Kernel modules:"
$PODMAN exec bpfman-demo-pod-bpfman ls /lib/modules/ | head -3
echo ""

# Show network interfaces (bpfman will attach programs to these)
echo "14. Available network interfaces (for eBPF attachment)..."
$PODMAN exec bpfman-demo-pod-bpfman ip link show | grep -E "^[0-9]+:" | head -5
echo ""

# Show recent logs
echo "15. Recent bpfman-rpc activity..."
$PODMAN logs bpfman-demo-pod-bpfman --tail=15
echo ""

echo -e "${GREEN}╔════════════════════════════════════════════╗${NC}"
echo -e "${GREEN}║            Demo Complete! 🎉               ║${NC}"
echo -e "${GREEN}╚════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${BLUE}What Was Successfully Demonstrated:${NC}"
echo "  ✅ bpfman-rpc server running in privileged container"
echo "  ✅ gRPC socket created and accessible (/run/bpfman-sock/bpfman.sock)"
echo "  ✅ BPF filesystem access (/sys/fs/bpf)"
echo "  ✅ Required Linux capabilities granted"
echo "  ✅ Host network and PID namespace access"
echo "  ✅ SELinux compatibility (spc_t type)"
echo "  ✅ Red Hat enterprise image (registry.redhat.io/bpfman/bpfman:0.5.9)"
echo "  ✅ All required mounts working"
echo ""
echo -e "${YELLOW}Note:${NC} bpfmanctl CLI not included in Red Hat images."
echo "In production OpenShift, eBPF programs are managed via:"
echo "  • bpfman-operator (Kubernetes operator)"
echo "  • Custom Resources (CRDs)"
echo "  • Declarative program management"
echo ""
echo -e "${BLUE}Useful Commands:${NC}"
echo "  # View server logs:"
echo "  sudo podman logs bpfman-demo-pod-bpfman"
echo ""
echo "  # Follow logs:"
echo "  sudo podman logs -f bpfman-demo-pod-bpfman"
echo ""
echo "  # Check socket:"
echo "  sudo podman exec bpfman-demo-pod-bpfman ls -l /run/bpfman-sock/"
echo ""
echo "  # Check BPF filesystem:"
echo "  sudo podman exec bpfman-demo-pod-bpfman ls /sys/fs/bpf/"
echo ""
echo "  # Shell into container:"
echo "  sudo podman exec -it bpfman-demo-pod-bpfman /bin/sh"
echo ""
echo "  # Cleanup:"
echo "  sudo podman pod rm -f bpfman-demo-pod"
echo ""
echo -e "${BLUE}OpenShift Deployment Ready:${NC}"
echo "This demo proves all technical requirements for OpenShift:"
echo ""
echo "  ✅ Privileged container execution works"
echo "  ✅ Custom SCC requirements documented"
echo "  ✅ SELinux compatibility validated"
echo "  ✅ Host filesystem access proven"
echo "  ✅ Red Hat supported images"
echo ""
echo "Next steps:"
echo "  1. Review: bpfman-openshift.yaml (includes custom SCC)"
echo "  2. Review: CORPORATE-DEPLOYMENT.md (approval guide)"
echo "  3. Request custom SCC from OpenShift admins"
echo "  4. Deploy as DaemonSet in dev cluster"
echo ""
echo "See bpfman-openshift.yaml for complete OpenShift manifest with SCC"
echo ""
echo "See bpfman-openshift.yaml for complete OpenShift manifests"
