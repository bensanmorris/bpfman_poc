# XDP Packet Counter → OpenTelemetry Demo

A production-ready demonstration of integrating eBPF/XDP packet counters with OpenTelemetry on RHEL9.

This extends your existing XDP packet counter by adding an OpenTelemetry exporter that reads BPF maps and exports comprehensive metrics with full protocol breakdown to Prometheus and Grafana.

## 🎉 What You Get

- ✅ **Total packet & byte counts** - Monitor overall traffic
- ✅ **Protocol breakdown** - TCP, UDP, ICMP, Other packets
- ✅ **IP version stats** - IPv4 vs IPv6 distribution  
- ✅ **Real-time packet rate** - Packets per second
- ✅ **Full observability stack** - OpenTelemetry → Prometheus → Grafana
- ✅ **Podman-native** - Rootless containers on RHEL9

## Architecture

```
XDP Program (kernel) - xdp_packet_counter
Attached to: enp1s0
      ↓
BPF Map: stats_map (64 bytes, 8 × u64)
  struct pkt_stats {
    total_packets, total_bytes,
    icmp_packets, tcp_packets, udp_packets,
    other_packets, ipv4_packets, ipv6_packets
  }
      ↓
OpenTelemetry Exporter (Python)
  - Reads via: bpftool map dump -j
  - Parses: entry['formatted']['value']
  - Exports: 9 OpenTelemetry metrics
      ↓
OpenTelemetry Collector (:4317)
  - OTLP gRPC receiver
  - Batch processor
  - Prometheus exporter (:8889)
      ↓
Prometheus (:9090)
  - Time-series database
  - 15s scrape interval
  - PromQL query engine
      ↓
Grafana (:3000)
  - Visualization dashboards
  - Real-time monitoring
```

## Prerequisites

### System Requirements
- **OS**: RHEL 9.x
- **Kernel**: 5.14+ (with eBPF/XDP support)
- **Tools**: bpftool, podman, python3
- **XDP Program**: Your packet counter must be loaded and attached

### Quick Check
```bash
# Verify XDP program is loaded
sudo bpftool prog list | grep xdp

# Verify it's attached to an interface  
sudo bpftool net show

# Verify the stats_map exists
sudo bpftool map list | grep stats_map

# Check current stats
sudo bpftool map dump name stats_map -j
```

## Installation

### Option 1: Automated Setup (Recommended)

```bash
cd xdp-otel-demo/

# 1. Install system dependencies and setup Podman
./setup-rhel9.sh

# 2. Setup Python virtual environment
./setup-venv.sh

# 3. Start monitoring stack
podman-compose up -d

# 4. Run the exporter
sudo -E venv/bin/python3 xdp_otel_exporter_enhanced.py --map-name stats_map
```

### Option 2: Manual Setup

```bash
# 1. Install system packages
sudo dnf install -y python3 python3-pip bpftool podman

# 2. Install podman-compose via pip
pip3 install --user podman-compose
export PATH="$HOME/.local/bin:$PATH"

# 3. Create Python virtual environment
python3 -m venv venv
source venv/bin/activate

# 4. Install OpenTelemetry packages
pip install opentelemetry-api \
            opentelemetry-sdk \
            opentelemetry-exporter-otlp-proto-grpc

# 5. Pull container images
podman pull docker.io/otel/opentelemetry-collector:latest
podman pull docker.io/prom/prometheus:latest
podman pull docker.io/grafana/grafana:latest
podman pull docker.io/jaegertracing/all-in-one:latest

# 6. Start the stack
podman-compose up -d
```

## Usage

### Start the Monitoring Stack

```bash
cd xdp-otel-demo/

# Start all services
podman-compose up -d

# Verify they're running (all should show "Up")
podman-compose ps

# Check logs if needed
podman-compose logs -f otel-collector
```

### Run the OpenTelemetry Exporter

```bash
# Activate virtual environment
source venv/bin/activate

# Run the exporter (reads stats_map and exports to OTel Collector)
sudo -E venv/bin/python3 xdp_otel_exporter_enhanced.py --map-name stats_map
```

**Expected Output:**
```
2026-01-19 11:00:01 - __main__ - INFO - Found map 'stats_map' with ID 9
2026-01-19 11:00:01 - __main__ - INFO - Enhanced XDP OpenTelemetry exporter initialized
2026-01-19 11:00:01 - __main__ - INFO -   OTLP endpoint: localhost:4317
2026-01-19 11:00:01 - __main__ - INFO -   Export interval: 10s
2026-01-19 11:00:01 - __main__ - INFO - XDP OpenTelemetry exporter running...
2026-01-19 11:00:02 - __main__ - INFO - Total: 6,180 pkts, 3,884,415 bytes | IPv4: 4,561, IPv6: 3 | TCP: 4,106, UDP: 408, ICMP: 50, Other: 1,616 | Rate: 123.45 pps
```

### View Metrics in Grafana

1. **Open Grafana**: http://localhost:3000
2. **Login**: admin / admin (change password on first login)
3. **Navigate**: Explore → Select "Prometheus" datasource
4. **Query Examples**:

```promql
# Total packet rate
rate(xdp_xdp_packets_total[1m])

# TCP packet rate
rate(xdp_xdp_packets_tcp[1m])

# UDP packet rate
rate(xdp_xdp_packets_udp[1m])

# ICMP packet rate
rate(xdp_xdp_packets_icmp[1m])

# Bandwidth (bytes/sec)
rate(xdp_xdp_bytes_total[1m])

# TCP percentage of total traffic
(rate(xdp_xdp_packets_tcp[5m]) / rate(xdp_xdp_packets_total[5m])) * 100

# IPv6 adoption percentage
(rate(xdp_xdp_packets_ipv6[5m]) / rate(xdp_xdp_packets_total[5m])) * 100

# Protocol breakdown - stacked area chart
rate(xdp_xdp_packets_tcp[1m])
+ rate(xdp_xdp_packets_udp[1m])
+ rate(xdp_xdp_packets_icmp[1m])
+ rate(xdp_xdp_packets_other[1m])
```

## Metrics Exported

The enhanced exporter sends **9 metrics** to OpenTelemetry:

| Metric Name | Type | Unit | Description | PromQL Name |
|-------------|------|------|-------------|-------------|
| `xdp.packets.total` | Counter | packets | Total packets processed | `xdp_xdp_packets_total` |
| `xdp.bytes.total` | Counter | bytes | Total bytes processed | `xdp_xdp_bytes_total` |
| `xdp.packets.tcp` | Counter | packets | TCP packets | `xdp_xdp_packets_tcp` |
| `xdp.packets.udp` | Counter | packets | UDP packets | `xdp_xdp_packets_udp` |
| `xdp.packets.icmp` | Counter | packets | ICMP packets | `xdp_xdp_packets_icmp` |
| `xdp.packets.other` | Counter | packets | Other protocol packets | `xdp_xdp_packets_other` |
| `xdp.packets.ipv4` | Counter | packets | IPv4 packets | `xdp_xdp_packets_ipv4` |
| `xdp.packets.ipv6` | Counter | packets | IPv6 packets | `xdp_xdp_packets_ipv6` |
| `xdp.packets.rate` | Gauge | packets/sec | Packet processing rate | `xdp_xdp_packets_rate` |

**Resource Attributes:**
- `service.name`: xdp-packet-counter
- `deployment.environment`: demo

## Advanced Usage

### Custom Export Interval

```bash
# Export every 5 seconds (default is 10)
sudo -E venv/bin/python3 xdp_otel_exporter_enhanced.py \
    --map-name stats_map \
    --interval 5
```

### Custom OpenTelemetry Endpoint

```bash
# Send to remote collector
sudo -E venv/bin/python3 xdp_otel_exporter_enhanced.py \
    --map-name stats_map \
    --otel-endpoint remote-collector.example.com:4317
```

### Debug Mode

```bash
# See detailed parsing and JSON structure
sudo -E venv/bin/python3 xdp_otel_exporter_enhanced.py \
    --map-name stats_map \
    --debug
```

### Using Map ID Instead of Name

```bash
# Find map ID
MAP_ID=$(sudo bpftool map list | grep stats_map | awk -F: '{print $1}')

# Use explicit ID
sudo -E venv/bin/python3 xdp_otel_exporter_enhanced.py \
    --map-id $MAP_ID
```

## Running as a Systemd Service

For production deployments, run the exporter as a systemd service:

```bash
# Create service file (adjust paths for your system)
sudo tee /etc/systemd/system/xdp-otel-exporter.service > /dev/null <<EOF
[Unit]
Description=XDP Packet Counter OpenTelemetry Exporter
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/home/benm/xdp-otel-demo
ExecStart=/home/benm/xdp-otel-demo/venv/bin/python3 /home/benm/xdp-otel-demo/xdp_otel_exporter_enhanced.py --map-name stats_map
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

# Enable and start
sudo systemctl daemon-reload
sudo systemctl enable xdp-otel-exporter
sudo systemctl start xdp-otel-exporter

# Check status
sudo systemctl status xdp-otel-exporter

# View logs
sudo journalctl -u xdp-otel-exporter -f
```

## Generating Test Traffic

To see your metrics change, generate some network traffic:

```bash
# ICMP traffic (will show in icmp_packets)
ping -c 100 8.8.8.8

# TCP traffic (will show in tcp_packets)
curl http://example.com
wget http://releases.ubuntu.com/20.04/ubuntu-20.04.6-desktop-amd64.iso

# UDP traffic (will show in udp_packets)
dig @8.8.8.8 google.com
nslookup example.com 8.8.8.8

# Mixed traffic script
cat > generate-traffic.sh << 'SCRIPT'
#!/bin/bash
echo "Generating mixed traffic..."
while true; do
    ping -c 5 8.8.8.8 > /dev/null 2>&1 &
    curl -s http://example.com > /dev/null 2>&1 &
    dig @8.8.8.8 google.com > /dev/null 2>&1 &
    echo "Batch sent... ($(date +%H:%M:%S))"
    sleep 2
done
SCRIPT
chmod +x generate-traffic.sh
./generate-traffic.sh
```

## Troubleshooting

### Exporter shows "Map not found"

```bash
# Check if map exists
sudo bpftool map list | grep stats

# If not found, verify XDP program is loaded
sudo bpftool prog list | grep xdp
sudo bpftool net show

# Load your XDP program if needed
```

### Exporter shows all zeros

```bash
# Check if map has data
sudo bpftool map dump name stats_map -j

# If all zeros, XDP program isn't processing packets
# Verify it's attached to the correct interface
sudo bpftool net show

# Generate traffic on that interface
ping -c 10 <interface-ip>
```

### OTel Collector not starting

```bash
# Check logs
podman-compose logs otel-collector

# Common issue: deprecated 'logging' exporter
# The otel-collector-config.yaml should use 'debug' not 'logging'

# Restart after fix
podman-compose restart otel-collector
```

### "No module named opentelemetry"

```bash
# Make sure venv is activated
source venv/bin/activate

# Verify packages are installed
pip list | grep opentelemetry

# Reinstall if needed
pip install opentelemetry-api opentelemetry-sdk opentelemetry-exporter-otlp-proto-grpc

# IMPORTANT: Use sudo -E to preserve venv environment
sudo -E venv/bin/python3 xdp_otel_exporter_enhanced.py --map-name stats_map
```

### Grafana shows no data

```bash
# 1. Verify exporter is running and sending metrics
# Check exporter output shows packet counts increasing

# 2. Verify OTel Collector is receiving metrics
podman-compose logs otel-collector | grep -i metric

# 3. Verify Prometheus is scraping
curl http://localhost:8889/metrics | grep xdp

# 4. Check Prometheus UI
firefox http://localhost:9090
# Query: xdp_xdp_packets_total

# 5. Verify Grafana datasource
# Settings → Data Sources → Prometheus
# URL should be: http://prometheus:9090
```

## Project Structure

```
xdp-otel-demo/
├── xdp_otel_exporter_enhanced.py  # Main exporter (protocol breakdown)
├── docker-compose.yml              # Monitoring stack definition
├── otel-collector-config.yaml     # OTel Collector configuration
├── prometheus.yml                  # Prometheus scrape config
├── grafana-datasources.yml         # Grafana datasource
├── requirements.txt                # Python dependencies
├── setup-rhel9.sh                  # Automated system setup
├── setup-venv.sh                   # Automated venv setup
├── README.md                       # This file
├── QUICKSTART.md                   # Quick reference
├── USING-YOUR-PROGRAM.md           # Guide for your XDP program
├── PODMAN-COMMANDS.md              # Podman reference
├── PODMAN-TROUBLESHOOTING.md       # Podman troubleshooting
├── ARCHITECTURE.md                 # Detailed architecture diagrams
├── RHEL9-SUMMARY.md                # RHEL9/Podman overview
├── MANUAL-INSTALL.md               # Manual installation guide
└── INDEX.md                        # Documentation index
```

## How It Works

1. **XDP Program** (kernel space)
   - Processes packets at the network driver level
   - Updates `stats_map` with packet counts per protocol

2. **BPF Map** (`stats_map`)
   - Array map with 1 entry (key=0)
   - Value is 64 bytes (8 × uint64 fields)
   - Shared between kernel and userspace

3. **OpenTelemetry Exporter** (Python)
   - Reads map using `bpftool map dump -j`
   - Parses JSON: `entry['formatted']['value']`
   - Converts to OpenTelemetry metrics
   - Sends via OTLP gRPC to collector

4. **OpenTelemetry Collector**
   - Receives OTLP on port 4317
   - Batches metrics for efficiency
   - Exports to Prometheus endpoint on 8889

5. **Prometheus**
   - Scrapes OTel Collector every 15s
   - Stores time-series data
   - Provides PromQL query engine

6. **Grafana**
   - Visualizes Prometheus metrics
   - Real-time dashboards
   - Alerting capabilities

## Production Considerations

### Security
- [ ] Enable TLS for OTLP endpoint
- [ ] Use authentication for Grafana
- [ ] Run exporter as non-root user (with CAP_BPF)
- [ ] Restrict container network access

### Performance
- [ ] Adjust export interval based on traffic volume
- [ ] Configure Prometheus retention policies
- [ ] Set resource limits in docker-compose.yml
- [ ] Monitor exporter CPU/memory usage

### Reliability
- [ ] Set up systemd service for exporter
- [ ] Configure automatic container restart
- [ ] Set up Prometheus/Grafana data backups
- [ ] Configure alerting rules for anomalies

### Observability
- [ ] Add custom Grafana dashboards
- [ ] Set up alerts for traffic anomalies
- [ ] Export to additional backends (Jaeger, Datadog, etc.)
- [ ] Add more metrics from your XDP program

## References

- [OpenTelemetry Python SDK](https://opentelemetry.io/docs/languages/python/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [PromQL Basics](https://prometheus.io/docs/prometheus/latest/querying/basics/)
- [RHEL9 eBPF Documentation](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_networking/assembly_understanding-the-ebpf-features-in-rhel-9_configuring-and-managing-networking)
- [bpftool Documentation](https://man7.org/linux/man-pages/man8/bpftool.8.html)
- [Rootless Podman](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)

## Contributing

This demo was created to showcase XDP integration with modern observability tools. Feel free to:
- Add more metrics from your XDP program
- Create custom Grafana dashboards
- Extend to other protocols
- Add alerting rules

## License

Same as your existing XDP packet counter demo.

---

**🎉 Congratulations!** You now have a complete eBPF/XDP observability pipeline with protocol-level insights exported to industry-standard monitoring tools!
