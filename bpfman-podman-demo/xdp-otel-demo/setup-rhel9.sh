#!/bin/bash
# setup-rhel9.sh - Setup script optimized for RHEL9 with Podman

set -e

echo "============================================"
echo "XDP → OpenTelemetry Demo Setup for RHEL9"
echo "============================================"
echo

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "This script will install and configure everything needed for the demo."
echo "Press Ctrl+C to cancel, or Enter to continue..."
read

echo
echo "Step 1: Installing required packages..."
sudo dnf install -y \
    python3 \
    python3-pip \
    bpftool \
    podman \
    podman-compose \
    netcat

echo
echo "Step 2: Installing Python OpenTelemetry packages..."
pip3 install --break-system-packages \
    opentelemetry-api \
    opentelemetry-sdk \
    opentelemetry-exporter-otlp-proto-grpc

echo
echo "Step 3: Configuring Podman for rootless operation..."

# Enable podman socket for rootless
systemctl --user enable --now podman.socket 2>/dev/null || true

# Configure subuids/subgids if not already done
if ! grep -q "^$(whoami):" /etc/subuid; then
    echo "$(whoami):100000:65536" | sudo tee -a /etc/subuid
fi
if ! grep -q "^$(whoami):" /etc/subgid; then
    echo "$(whoami):100000:65536" | sudo tee -a /etc/subgid
fi

# Migrate to cgroup v2 if needed (RHEL9 default)
if [ "$(stat -fc %T /sys/fs/cgroup/)" != "cgroup2fs" ]; then
    echo -e "${YELLOW}Warning: cgroup v2 not detected. This may affect container performance.${NC}"
fi

echo
echo "Step 4: Configuring SELinux labels for volumes..."
# Ensure SELinux allows container access to config files
if [ "$(getenforce)" != "Disabled" ]; then
    chcon -t container_file_t *.yaml *.yml 2>/dev/null || true
    echo -e "${GREEN}✓${NC} SELinux labels configured"
else
    echo "SELinux is disabled, skipping labeling"
fi

echo
echo "Step 5: Pulling container images..."
podman pull otel/opentelemetry-collector:latest
podman pull prom/prometheus:latest
podman pull grafana/grafana:latest
podman pull jaegertracing/all-in-one:latest

echo
echo "Step 6: Testing Podman setup..."
podman info | grep -E "(rootless|cgroupVersion)" || true

echo
echo "============================================"
echo -e "${GREEN}✓ Setup complete!${NC}"
echo "============================================"
echo
echo "Next steps:"
echo "  1. Start the monitoring stack:"
echo "     podman-compose up -d"
echo
echo "  2. Verify services are running:"
echo "     podman-compose ps"
echo
echo "  3. Run the demo exporter:"
echo "     sudo python3 xdp_otel_exporter_simple.py --map-name xdp_stats_map"
echo
echo "  4. Access services:"
echo "     - Grafana: http://localhost:3000 (admin/admin)"
echo "     - Prometheus: http://localhost:9090"
echo "     - Jaeger: http://localhost:16686"
echo
echo "For troubleshooting, see README.md"
echo
