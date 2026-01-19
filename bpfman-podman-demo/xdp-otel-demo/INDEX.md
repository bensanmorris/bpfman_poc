# XDP → OpenTelemetry Demo - Documentation Index

## 📚 Quick Navigation

### 🚀 Getting Started (Read These First)
1. **[RHEL9-SUMMARY.md](RHEL9-SUMMARY.md)** - Start here! Overview of the whole demo
2. **[QUICKSTART.md](QUICKSTART.md)** - Quick reference cheat sheet
3. **[setup-rhel9.sh](setup-rhel9.sh)** - Run this to install everything automatically

### 📖 Main Documentation
4. **[README.md](README.md)** - Complete detailed documentation
5. **[ARCHITECTURE.md](ARCHITECTURE.md)** - Visual diagrams of how everything works

### 🐳 Podman-Specific (RHEL9)
6. **[PODMAN-COMMANDS.md](PODMAN-COMMANDS.md)** - Podman command reference
7. **[PODMAN-TROUBLESHOOTING.md](PODMAN-TROUBLESHOOTING.md)** - Fix common Podman issues

### 🛠️ Scripts & Tools
8. **[xdp_otel_exporter_simple.py](xdp_otel_exporter_simple.py)** - Main exporter (recommended)
9. **[xdp_otel_exporter.py](xdp_otel_exporter.py)** - Alternative BCC-based exporter
10. **[test-setup.sh](test-setup.sh)** - Verify the installation

### ⚙️ Configuration Files
11. **[docker-compose.yml](docker-compose.yml)** - Container stack definition
12. **[otel-collector-config.yaml](otel-collector-config.yaml)** - OpenTelemetry config
13. **[prometheus.yml](prometheus.yml)** - Prometheus scrape config
14. **[grafana-datasources.yml](grafana-datasources.yml)** - Grafana data sources
15. **[requirements.txt](requirements.txt)** - Python dependencies

---

## 🎯 Usage Guides by Scenario

### "I want to get started quickly"
1. Read: [RHEL9-SUMMARY.md](RHEL9-SUMMARY.md)
2. Run: `./setup-rhel9.sh`
3. Run: `podman-compose up -d`
4. Run: `sudo python3 xdp_otel_exporter_simple.py --map-name xdp_stats_map`
5. Open: http://localhost:3000

### "I'm having Podman problems"
1. Check: [PODMAN-TROUBLESHOOTING.md](PODMAN-TROUBLESHOOTING.md)
2. Reference: [PODMAN-COMMANDS.md](PODMAN-COMMANDS.md)
3. Run: `./test-setup.sh`

### "I want to understand how it works"
1. Read: [ARCHITECTURE.md](ARCHITECTURE.md)
2. Read: [README.md](README.md) (Detailed docs)
3. Look at: [otel-collector-config.yaml](otel-collector-config.yaml)

### "I need a quick command reference"
1. See: [QUICKSTART.md](QUICKSTART.md)
2. See: [PODMAN-COMMANDS.md](PODMAN-COMMANDS.md)

### "I'm extending this for production"
1. Read: [README.md](README.md) - "Production Considerations"
2. Review: [RHEL9-SUMMARY.md](RHEL9-SUMMARY.md) - "Production Deployment"
3. Check: [otel-collector-config.yaml](otel-collector-config.yaml) - Add TLS

---

## 📋 Document Descriptions

| File | Purpose | Read Time | Skill Level |
|------|---------|-----------|-------------|
| RHEL9-SUMMARY.md | High-level overview for RHEL9/Podman | 5 min | Beginner |
| QUICKSTART.md | Commands cheat sheet | 2 min | Beginner |
| README.md | Complete detailed docs | 15 min | All levels |
| ARCHITECTURE.md | System diagrams | 5 min | Intermediate |
| PODMAN-COMMANDS.md | Podman command reference | 5 min | Beginner |
| PODMAN-TROUBLESHOOTING.md | Fix Podman issues | 10 min | Intermediate |
| setup-rhel9.sh | Automated setup script | N/A | N/A |
| test-setup.sh | Verification script | N/A | N/A |

---

## 🔧 Component Reference

### Python Exporters
```bash
# Lightweight, uses bpftool (RECOMMENDED)
python3 xdp_otel_exporter_simple.py --map-name xdp_stats_map

# Advanced, uses BCC library
python3 xdp_otel_exporter.py --map-path /sys/fs/bpf/xdp_stats_map
```

### Container Services
```bash
# OpenTelemetry Collector
http://localhost:4317  # gRPC endpoint
http://localhost:8889  # Prometheus metrics

# Prometheus
http://localhost:9090  # Query UI

# Grafana
http://localhost:3000  # Dashboard UI (admin/admin)

# Jaeger
http://localhost:16686 # Trace UI
```

### Configuration Files
```yaml
# Stack definition
docker-compose.yml

# OpenTelemetry processing
otel-collector-config.yaml

# Prometheus scraping
prometheus.yml

# Grafana datasources
grafana-datasources.yml
```

---

## 🎓 Learning Path

### Level 1: Basic Usage
1. Read [RHEL9-SUMMARY.md](RHEL9-SUMMARY.md)
2. Run `./setup-rhel9.sh`
3. Follow [QUICKSTART.md](QUICKSTART.md)
4. Explore Grafana at http://localhost:3000

### Level 2: Understanding Components
1. Read [ARCHITECTURE.md](ARCHITECTURE.md)
2. Study [otel-collector-config.yaml](otel-collector-config.yaml)
3. Learn Podman: [PODMAN-COMMANDS.md](PODMAN-COMMANDS.md)
4. Review exporter code: [xdp_otel_exporter_simple.py](xdp_otel_exporter_simple.py)

### Level 3: Customization
1. Modify [otel-collector-config.yaml](otel-collector-config.yaml)
2. Add exporters (Jaeger, Datadog, etc.)
3. Create Grafana dashboards
4. Extend Python exporter for custom metrics

### Level 4: Production Deployment
1. Read [README.md](README.md) production section
2. Configure TLS in [otel-collector-config.yaml](otel-collector-config.yaml)
3. Set up systemd services
4. Configure backups and monitoring

---

## 🆘 Troubleshooting Quick Links

### Common Issues

**"Podman not found"**
→ See [PODMAN-TROUBLESHOOTING.md](PODMAN-TROUBLESHOOTING.md) - Installation

**"Permission denied"**
→ See [PODMAN-TROUBLESHOOTING.md](PODMAN-TROUBLESHOOTING.md) - SELinux

**"Can't find BPF map"**
→ See [README.md](README.md) - Troubleshooting section

**"Port already in use"**
→ See [PODMAN-TROUBLESHOOTING.md](PODMAN-TROUBLESHOOTING.md) - Port conflicts

**"No metrics in Prometheus"**
→ See [README.md](README.md) - Troubleshooting section

---

## 📞 Getting Help

### Check These Resources
1. Run diagnostic: `./test-setup.sh`
2. Check logs: `podman-compose logs -f`
3. Review troubleshooting: [PODMAN-TROUBLESHOOTING.md](PODMAN-TROUBLESHOOTING.md)

### External Resources
- [RHEL9 Containers Docs](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/building_running_and_managing_containers/)
- [OpenTelemetry Docs](https://opentelemetry.io/docs/)
- [Podman Documentation](https://docs.podman.io/)

---

## 🎯 Files by Purpose

### Setup & Installation
- `setup-rhel9.sh` - Automated RHEL9 setup
- `test-setup.sh` - Verify installation
- `requirements.txt` - Python packages

### Documentation
- `RHEL9-SUMMARY.md` - RHEL9/Podman overview
- `README.md` - Complete documentation
- `QUICKSTART.md` - Quick reference
- `ARCHITECTURE.md` - System diagrams
- `PODMAN-COMMANDS.md` - Podman commands
- `PODMAN-TROUBLESHOOTING.md` - Fix issues
- `INDEX.md` - This file

### Application Code
- `xdp_otel_exporter_simple.py` - Main exporter
- `xdp_otel_exporter.py` - Alternative exporter

### Configuration
- `docker-compose.yml` - Container stack
- `otel-collector-config.yaml` - OTel config
- `prometheus.yml` - Prometheus config
- `grafana-datasources.yml` - Grafana config

---

## 🌟 Highlights for RHEL9 Users

✅ **Podman-native** - No Docker required  
✅ **SELinux compatible** - Works with security enabled  
✅ **Rootless by default** - No root privileges needed  
✅ **Firewalld integrated** - Proper port management  
✅ **systemd services** - Native service management  
✅ **Red Hat supported** - Uses RHEL9 tools and patterns  

---

**Last Updated**: 2025-01-13  
**RHEL Version**: 9.x  
**Podman Version**: 4.x+  
**Python Version**: 3.9+
