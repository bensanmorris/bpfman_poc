# XDP → OpenTelemetry Quick Reference

## Setup (One-time)

```bash
# Install dependencies on RHEL9
sudo dnf install -y python3 python3-pip bpftool podman podman-compose
pip3 install --break-system-packages opentelemetry-api opentelemetry-sdk opentelemetry-exporter-otlp-proto-grpc

# OR use the automated setup script
./setup-rhel9.sh

# Start monitoring stack
cd /path/to/xdp-otel-demo
podman-compose up -d

# Verify setup
./test-setup.sh
```

## Running the Demo

```bash
# 1. Find the XDP map ID
bpftool map list | grep xdp_stats
# Output: 123: hash  name xdp_stats_map ...

# 2. Run the OpenTelemetry exporter
sudo python3 xdp_otel_exporter_simple.py --map-id 123

# OR auto-detect by name
sudo python3 xdp_otel_exporter_simple.py --map-name xdp_stats_map
```

## Viewing Metrics

### Prometheus (Raw Metrics)
- URL: http://localhost:9090
- Query: `xdp_xdp_packets_total`

### Grafana (Dashboards)
- URL: http://localhost:3000
- User: admin / admin
- Explore → Select Prometheus → Query metrics

### OpenTelemetry Collector (Debug)
```bash
# View raw metrics
curl http://localhost:8889/metrics | grep xdp

# View collector logs
podman-compose logs -f otel-collector
```

## Useful Commands

```bash
# Check if exporter is sending metrics
podman-compose logs otel-collector | grep xdp

# Monitor packet rate
watch -n1 'curl -s http://localhost:8889/metrics | grep xdp_packets'

# Generate traffic for testing
sudo hping3 -S -p 80 --flood <target-ip>

# Stop the stack
podman-compose down

# Stop and clean up
podman-compose down -v
```

## Example PromQL Queries

```promql
# Packet rate (packets/sec)
rate(xdp_xdp_packets_total[1m])

# Bytes rate (bytes/sec)
rate(xdp_xdp_bytes_total[1m])

# Average packet size
rate(xdp_xdp_bytes_total[1m]) / rate(xdp_xdp_packets_total[1m])

# Total packets in last hour
increase(xdp_xdp_packets_total[1h])
```

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Can't find map | `sudo bpftool map list` - ensure XDP program is loaded |
| Permission denied | Run with `sudo` - needs CAP_BPF |
| No metrics in Prometheus | Check `podman-compose logs otel-collector` |
| Connection refused | Ensure stack is running: `podman-compose ps` |

## File Structure

```
xdp-otel-demo/
├── xdp_otel_exporter_simple.py   ← Main exporter (bpftool-based)
├── docker-compose.yml             ← Full monitoring stack
├── otel-collector-config.yaml    ← OTel configuration
├── prometheus.yml                 ← Prometheus config
├── test-setup.sh                  ← Verification script
├── README.md                      ← Full documentation
└── requirements.txt               ← Python dependencies
```

## RHEL9 / Podman Notes

### Rootless Podman (Recommended)
```bash
# Run containers as regular user (no sudo needed)
podman-compose up -d

# If you need rootful mode:
sudo podman-compose up -d
```

### SELinux Considerations
```bash
# Volume mounts have :Z suffix for SELinux compatibility
# Already configured in docker-compose.yml

# If you get permission errors:
sudo setenforce 0  # Temporarily (testing only)
# OR
chcon -R -t container_file_t .
```

### Firewall
```bash
# If services aren't accessible from other machines:
sudo firewall-cmd --add-port=3000/tcp --permanent
sudo firewall-cmd --add-port=9090/tcp --permanent
sudo firewall-cmd --add-port=4317/tcp --permanent
sudo firewall-cmd --reload
```

See `PODMAN-TROUBLESHOOTING.md` for more details.

## Red Hat Pattern

This demo follows the recommended RHEL9 eBPF → OpenTelemetry pattern:

1. **eBPF Program**: Uses libxdp (RHEL9 requirement)
2. **User-space Collector**: Reads BPF maps via bpftool (no BCC dependency)
3. **OpenTelemetry Export**: Standard OTLP/gRPC protocol
4. **Backend-Agnostic**: Works with any OTel-compatible backend

This is the lightweight, production-ready pattern without operator overhead.
