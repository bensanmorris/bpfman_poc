# XDP → OpenTelemetry Demo: RHEL9 Edition

## Overview

This demo extends the existing XDP packet counter by adding OpenTelemetry export capabilities, optimized specifically for **Red Hat Enterprise Linux 9** using **Podman** (Red Hat's container runtime).

## Why This Approach?

✅ **Lightweight**: Extends the existing demo without operator complexity  
✅ **RHEL9 Native**: Uses Podman, not Docker  
✅ **Production-Ready**: Follows Red Hat's recommended patterns  
✅ **Easy Integration**: Works alongside the current Python/libbpf scrapers  
✅ **Vendor-Neutral**: OpenTelemetry works with any backend  

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│                     RHEL9 Host                           │
├─────────────────────────────────────────────────────────┤
│                                                           │
│  XDP Program (kernel) ← The existing demo              │
│       ↓                                                   │
│  BPF Maps (packet_stats)                                │
│       ↓                                                   │
│  ┌──────────────┬──────────────┬─────────────────┐     │
│  │ Python       │ libbpf       │ NEW: Python     │     │
│  │ bpftool      │ (C-based)    │ OpenTelemetry   │     │
│  │ scraper      │ scraper      │ Exporter        │     │
│  └──────────────┴──────────────┴─────────────────┘     │
│                                      ↓                    │
│  ┌────────────────────────────────────────────────┐     │
│  │        Podman Containers (rootless)             │     │
│  │  ┌──────────────────────────────────────────┐  │     │
│  │  │ OpenTelemetry Collector (port 4317)      │  │     │
│  │  │           ↓                               │  │     │
│  │  │ Prometheus (port 9090)                   │  │     │
│  │  │           ↓                               │  │     │
│  │  │ Grafana (port 3000)                      │  │     │
│  │  └──────────────────────────────────────────┘  │     │
│  └────────────────────────────────────────────────┘     │
└─────────────────────────────────────────────────────────┘
```

## RHEL9-Specific Features

### 1. Podman (Not Docker)
- **Native to RHEL9**: Podman is Red Hat's container engine
- **Rootless by default**: More secure than Docker
- **systemd integration**: Native Linux service management
- **SELinux compatible**: Works with RHEL security policies
- **cgroup v2 support**: Modern resource management

### 2. SELinux Support
All volume mounts use `:Z` suffix for proper SELinux labeling:
```yaml
volumes:
  - ./config.yaml:/etc/config.yaml:Z
```

### 3. User Namespaces
Containers run with proper UID mapping:
```yaml
services:
  otel-collector:
    userns_mode: "keep-id"
```

### 4. Firewalld Integration
The setup script configures firewall rules:
```bash
sudo firewall-cmd --add-port=4317/tcp --permanent
```

## Quick Start (3 Steps)

### Step 1: Automated Setup
```bash
# Run the RHEL9 setup script
./setup-rhel9.sh
```

This installs:
- Python 3 + OpenTelemetry packages
- bpftool
- Podman + podman-compose
- Configures SELinux labels
- Pulls container images

### Step 2: Start Monitoring Stack
```bash
# Start all services with Podman
podman-compose up -d

# Verify (should see 4 containers running)
podman-compose ps
```

### Step 3: Run OpenTelemetry Exporter
```bash
# Auto-discover the XDP map and export metrics
sudo python3 xdp_otel_exporter_simple.py --map-name xdp_stats_map
```

**That's it!** Open http://localhost:3000 (Grafana) to see the metrics.

## What You Get

### 1. OpenTelemetry Exporter (`xdp_otel_exporter_simple.py`)
- Reads from BPF maps using `bpftool` (RHEL9 standard tool)
- No BCC dependency (lightweight)
- Exports to OpenTelemetry Collector via gRPC
- Tracks: packets/sec, bytes/sec, total counts

### 2. Complete Monitoring Stack (Podman containers)
- **OpenTelemetry Collector**: Receives and processes metrics
- **Prometheus**: Stores time-series data
- **Grafana**: Visualizes metrics with dashboards
- **Jaeger**: Optional distributed tracing

### 3. Production-Ready Configuration
- SELinux compatible
- Firewall rules
- Resource limits
- Proper logging
- Health checks

## RHEL9 Best Practices Included

✅ **Rootless Podman**: Runs as regular user, no root needed  
✅ **SELinux Enforcement**: All contexts properly configured  
✅ **Firewalld Integration**: Ports properly opened  
✅ **systemd Service**: Can run as system service  
✅ **Python PEP 668**: Uses `--break-system-packages` correctly  
✅ **cgroup v2**: Optimized resource management  
✅ **User Namespaces**: Proper UID/GID mapping  

## Differences from Docker

| Feature | Docker | Podman (RHEL9) |
|---------|--------|----------------|
| Daemon | Yes (dockerd) | No (daemonless) |
| Root required | Often yes | No (rootless) |
| Command | `docker-compose` | `podman-compose` |
| Security | Daemon runs as root | Runs as user |
| systemd | Manual integration | Native support |
| SELinux | Often disabled | Fully supported |
| Red Hat Support | Community only | Fully supported |

## File Structure

```
xdp-otel-demo/
├── xdp_otel_exporter_simple.py      ← Main exporter (bpftool)
├── xdp_otel_exporter.py              ← Alternative (BCC-based)
├── docker-compose.yml                ← Podman-compatible stack
├── otel-collector-config.yaml        ← OTel Collector config
├── prometheus.yml                    ← Prometheus config
├── grafana-datasources.yml           ← Grafana config
├── requirements.txt                  ← Python dependencies
├── setup-rhel9.sh                    ← Automated RHEL9 setup ⭐
├── test-setup.sh                     ← Verify installation
├── README.md                         ← Full documentation
├── QUICKSTART.md                     ← Quick reference
├── PODMAN-COMMANDS.md                ← Podman cheat sheet ⭐
└── PODMAN-TROUBLESHOOTING.md         ← Podman issues & fixes ⭐
```

⭐ = RHEL9/Podman specific

## Key Commands

```bash
# Setup (one-time)
./setup-rhel9.sh

# Start monitoring
podman-compose up -d

# Run exporter
sudo python3 xdp_otel_exporter_simple.py --map-name xdp_stats_map

# View logs
podman-compose logs -f

# Stop everything
podman-compose down

# Clean up completely
podman-compose down -v
podman system prune -a
```

## Troubleshooting

See `PODMAN-TROUBLESHOOTING.md` for detailed solutions to:
- SELinux permission errors
- Podman socket issues
- Port conflicts
- Volume permissions
- Network connectivity
- Firewall configuration

Quick diagnostics:
```bash
# Check everything
./test-setup.sh

# Verify Podman works
podman info | grep rootless

# Check SELinux
getenforce

# View container logs
podman-compose logs otel-collector
```

## Production Deployment

For production use on RHEL9:

1. **Run as systemd service**:
```bash
podman generate systemd --new --name otel-collector > otel-collector.service
sudo mv otel-collector.service /etc/systemd/system/
sudo systemctl enable --now otel-collector
```

2. **Enable TLS** in `otel-collector-config.yaml`:
```yaml
exporters:
  otlp:
    tls:
      cert_file: /path/to/cert.pem
      key_file: /path/to/key.pem
```

3. **Configure backups**:
```bash
# Backup Prometheus data
podman volume export prometheus-data > prometheus-backup.tar
```

4. **Set resource limits** in `docker-compose.yml`:
```yaml
deploy:
  resources:
    limits:
      cpus: '1.0'
      memory: 512M
```

## Why Podman for RHEL9?

1. **Red Hat Support**: Fully supported by Red Hat subscription
2. **Security**: Rootless by default, no privileged daemon
3. **Compatibility**: Drop-in replacement for Docker
4. **Integration**: Native systemd and SELinux support
5. **Future-proof**: Red Hat's strategic direction for containers

## Next Steps

1. **View metrics**: Open http://localhost:3000 (admin/admin)
2. **Create dashboards**: Build custom Grafana dashboards
3. **Add alerts**: Configure Prometheus alerting rules
4. **Scale up**: Add more exporters for other XDP programs
5. **Cloud export**: Configure cloud backends (Datadog, New Relic, etc.)

## Support & Documentation

- **Podman Commands**: See `PODMAN-COMMANDS.md`
- **Troubleshooting**: See `PODMAN-TROUBLESHOOTING.md`
- **Quick Reference**: See `QUICKSTART.md`
- **Full Docs**: See `README.md`

## RHEL Subscription

This demo works on:
- ✅ RHEL 9 with active subscription
- ✅ CentOS Stream 9
- ✅ AlmaLinux 9
- ✅ Rocky Linux 9

Verify subscription:
```bash
sudo subscription-manager status
```

## Comparison: bpfman-operator vs This Approach

| Aspect | bpfman-operator | This Demo |
|--------|----------------|-----------|
| **Complexity** | High (Kubernetes, CRDs, operators) | Low (standalone) |
| **Setup Time** | Hours | Minutes |
| **Dependencies** | Kubernetes/OpenShift required | Just Podman |
| **Use Case** | Production Kubernetes clusters | Demo, development, simple deployments |
| **Learning Curve** | Steep | Gentle |
| **Flexibility** | High (once set up) | High (immediate) |

**When to use each:**
- **This demo**: Learning, development, simple deployments, proof-of-concept
- **bpfman-operator**: Production Kubernetes, multiple nodes, enterprise scale

## License

Same as the existing XDP packet counter demo.

---

**Built for RHEL9 with ❤️ using Podman**
