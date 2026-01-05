#!/bin/bash
# Clean up bpfman demo

set -e

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Cleaning up bpfman demo..."
echo ""

echo "1. Stopping and removing pod..."
podman pod rm -f bpfman-demo-pod 2>/dev/null || echo "  (rootless) Pod not found"
sudo podman pod rm -f bpfman-demo-pod 2>/dev/null || echo "  (rootful) Pod not found"

echo ""
echo "2. Checking for leftover containers..."
LEFTOVER=$(podman ps -a --filter label=app=bpfman --format '{{.Names}}' 2>/dev/null || true)
if [ -n "$LEFTOVER" ]; then
    echo "  Found: $LEFTOVER"
    echo "$LEFTOVER" | xargs -r podman rm -f
else
    echo "  None found (rootless)"
fi

LEFTOVER_ROOT=$(sudo podman ps -a --filter label=app=bpfman --format '{{.Names}}' 2>/dev/null || true)
if [ -n "$LEFTOVER_ROOT" ]; then
    echo "  Found: $LEFTOVER_ROOT"
    echo "$LEFTOVER_ROOT" | xargs -r sudo podman rm -f
else
    echo "  None found (rootful)"
fi

echo ""
echo "3. Removing generated files..."
rm -f bpfman-pod.yaml

echo ""
echo "4. Current podman status:"
echo ""
echo "Pods:"
sudo podman pod ps
echo ""
echo "Containers:"
sudo podman ps -a

echo ""
echo -e "${GREEN}✓ Cleanup complete${NC}"
echo ""
echo "To re-run the demo:"
echo "  ./02-run-demo.sh"
