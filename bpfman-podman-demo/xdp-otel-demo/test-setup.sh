#!/bin/bash
# test-setup.sh - Verify the OpenTelemetry demo setup

set -e

echo "============================================"
echo "XDP → OpenTelemetry Demo Setup Verification"
echo "============================================"
echo

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

check_command() {
    if command -v "$1" &> /dev/null; then
        echo -e "${GREEN}✓${NC} $1 is installed"
        return 0
    else
        echo -e "${RED}✗${NC} $1 is NOT installed"
        return 1
    fi
}

check_port() {
    if nc -z localhost "$1" 2>/dev/null; then
        echo -e "${GREEN}✓${NC} Port $1 is open ($2)"
        return 0
    else
        echo -e "${RED}✗${NC} Port $1 is NOT open ($2)"
        return 1
    fi
}

echo "1. Checking required commands..."
ALL_GOOD=true
check_command python3 || ALL_GOOD=false
check_command bpftool || ALL_GOOD=false
check_command podman || ALL_GOOD=false
check_command podman-compose || ALL_GOOD=false
echo

echo "2. Checking Python packages..."
if python3 -c "import opentelemetry.sdk" 2>/dev/null; then
    echo -e "${GREEN}✓${NC} OpenTelemetry SDK is installed"
else
    echo -e "${RED}✗${NC} OpenTelemetry SDK is NOT installed"
    echo -e "   Install with: pip3 install --break-system-packages opentelemetry-sdk opentelemetry-exporter-otlp-proto-grpc"
    ALL_GOOD=false
fi
echo

echo "3. Checking BPF maps..."
if sudo bpftool map list | grep -q "xdp\|stats"; then
    echo -e "${GREEN}✓${NC} BPF maps found:"
    sudo bpftool map list | grep -i "xdp\|stats" | head -3
else
    echo -e "${YELLOW}⚠${NC} No XDP/stats BPF maps found"
    echo "   Make sure the XDP program is running"
fi
echo

echo "4. Checking OpenTelemetry stack services..."
check_port 4317 "OTel Collector gRPC" || echo "   Start with: podman-compose up -d"
check_port 9090 "Prometheus" || echo "   Start with: podman-compose up -d"
check_port 3000 "Grafana" || echo "   Start with: podman-compose up -d"
echo

echo "5. Testing OpenTelemetry Collector..."
if curl -s http://localhost:8889/metrics > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} OTel Collector metrics endpoint responding"
else
    echo -e "${RED}✗${NC} OTel Collector metrics endpoint not responding"
    echo "   Check logs with: podman-compose logs otel-collector"
fi
echo

echo "6. Configuration files..."
for file in docker-compose.yml otel-collector-config.yaml prometheus.yml; do
    if [ -f "$file" ]; then
        echo -e "${GREEN}✓${NC} $file exists"
    else
        echo -e "${RED}✗${NC} $file is missing"
        ALL_GOOD=false
    fi
done
echo

echo "============================================"
if [ "$ALL_GOOD" = true ]; then
    echo -e "${GREEN}✓ Setup looks good! Ready to run the demo.${NC}"
    echo
    echo "Next steps:"
    echo "  1. Start monitoring stack: podman-compose up -d"
    echo "  2. Find the map ID: bpftool map list | grep stats_map"
    echo "  3. Run exporter: sudo python3 xdp_otel_exporter_simple.py --map-id <ID>"
    echo "  4. View metrics: http://localhost:3000"
else
    echo -e "${RED}✗ Some components are missing. Please install them first.${NC}"
fi
echo "============================================"
