# XDP Packet Counter → OpenTelemetry Demo

A lightweight demonstration of integrating eBPF/XDP packet counters with OpenTelemetry on RHEL9.

This extends the existing XDP packet counter demo by adding an OpenTelemetry exporter that reads from the same BPF maps and forwards metrics to an OpenTelemetry backend.

## Architecture

```
┌─────────────────────────────────────────────────┐
│  XDP Program (kernel)                            │
│       ↓                                           │
│  BPF Maps (packet_stats)                        │
│       ↓                                           │
│  Python/bpftool Scraper                         │
│       ↓                                           │
│  OpenTelemetry Exporter (NEW)                   │
│       ↓                                           │
│  OpenTelemetry Collector                        │
│       ↓                                           │
│  Prometheus → Grafana                            │
└─────────────────────────────────────────────────┘
```

## Prerequisites

### On RHEL9 Host:
```bash
# Install required packages
sudo dnf install -y python3 python3-pip bpftool

# Install Python OpenTelemetry packages
pip3 install --break-system-packages opentelemetry-api opentelemetry-sdk opentelemetry-exporter-otlp-proto-grpc

# The XDP program should already be loaded and running
# Verify with: bpftool prog list
```

### For OpenTelemetry Backend (Podman on RHEL9):
```bash
# Install podman and podman-compose
sudo dnf install -y podman podman-compose

# OR use the automated setup script
./setup-rhel9.sh
```

## Quick Start

### Step 1: Start OpenTelemetry Stack

```bash
# Start the monitoring stack (OTel Collector, Prometheus, Grafana)
podman-compose up -d

# Verify services are running
podman-compose ps

# View logs if needed
podman-compose logs -f
```

The following services will be available:
- **OpenTelemetry Collector**: `localhost:4317` (gRPC), `localhost:4318` (HTTP)
- **Prometheus**: `http://localhost:9090`
- **Grafana**: `http://localhost:3000` (admin/admin)
- **Jaeger** (optional): `http://localhost:16686`

### Step 2: Run The XDP Program

```bash
# Make sure the XDP packet counter is loaded and running
# (Use the existing demo setup)

# Verify the BPF map exists
bpftool map list | grep xdp_stats

# Example output:
# 123: hash  name xdp_stats_map  flags 0x0
#         key 4B  value 16B  max_entries 1  memlock 4096B
```

### Step 3: Run the OpenTelemetry Exporter

```bash
# Find the map ID
MAP_ID=$(bpftool map list | grep xdp_stats | awk -F: '{print $1}')

# Run the exporter
sudo python3 xdp_otel_exporter_simple.py \
    --map-id $MAP_ID \
    --otel-endpoint localhost:4317 \
    --interval 5
```

You should see output like:
```
2025-01-13 10:30:45 - __main__ - INFO - XDP OpenTelemetry exporter initialized
2025-01-13 10:30:45 - __main__ - INFO -   OTLP endpoint: localhost:4317
2025-01-13 10:30:45 - __main__ - INFO -   Export interval: 5s
2025-01-13 10:30:45 - __main__ - INFO - XDP OpenTelemetry exporter running...
2025-01-13 10:30:46 - __main__ - INFO - Stats - Packets: 1,234, Bytes: 567,890, Rate: 123.45 pkt/s
```

### Step 4: View Metrics in Grafana

1. Open Grafana: `http://localhost:3000`
2. Login with `admin/admin`
3. Go to **Explore** → Select **Prometheus** datasource
4. Query examples:
   ```promql
   # Total packets
   xdp_xdp_packets_total
   
   # Packet rate
   rate(xdp_xdp_packets_total[1m])
   
   # Bytes per second
   rate(xdp_xdp_bytes_total[1m])
   ```

## Usage Examples

### Basic Usage
```bash
# Using map name (auto-discovers map ID)
sudo python3 xdp_otel_exporter_simple.py --map-name xdp_stats_map

# Using explicit map ID
sudo python3 xdp_otel_exporter_simple.py --map-id 123

# Custom OTel endpoint
sudo python3 xdp_otel_exporter_simple.py \
    --map-name xdp_stats_map \
    --otel-endpoint remote-collector.example.com:4317

# Faster export interval (2 seconds)
sudo python3 xdp_otel_exporter_simple.py \
    --map-name xdp_stats_map \
    --interval 2
```

### Running as a Service

Create a systemd service for continuous monitoring:

```bash
sudo tee /etc/systemd/system/xdp-otel-exporter.service > /dev/null <<EOF
[Unit]
Description=XDP Packet Counter OpenTelemetry Exporter
After=network.target

[Service]
Type=simple
User=root
WorkingDirectory=/path/to/xdp-otel-demo
ExecStart=/usr/bin/python3 /path/to/xdp-otel-demo/xdp_otel_exporter_simple.py --map-name xdp_stats_map --otel-endpoint localhost:4317
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable xdp-otel-exporter
sudo systemctl start xdp-otel-exporter
sudo systemctl status xdp-otel-exporter
```

## Metrics Exported

The exporter sends these metrics to OpenTelemetry:

| Metric Name | Type | Unit | Description |
|-------------|------|------|-------------|
| `xdp.packets.total` | Counter | packets | Total packets processed by XDP |
| `xdp.bytes.total` | Counter | bytes | Total bytes processed by XDP |
| `xdp.packets.rate` | Gauge | packets/sec | Current packet processing rate |

All metrics include resource attributes:
- `service.name`: xdp-packet-counter
- `deployment.environment`: demo

## Troubleshooting

### Exporter can't find BPF map
```bash
# List all BPF maps
bpftool map list

# Check if the XDP program is loaded
bpftool prog list | grep xdp

# Verify map is pinned
ls -la /sys/fs/bpf/
```

### Can't connect to OpenTelemetry Collector
```bash
# Check if OTel collector is running
podman-compose ps otel-collector

# Check collector logs
podman-compose logs otel-collector

# Test connectivity
nc -zv localhost 4317
```

### No metrics in Prometheus
```bash
# Check OTel Collector metrics endpoint
curl http://localhost:8889/metrics

# Check Prometheus targets
# Open http://localhost:9090/targets
```

### Permission denied errors
```bash
# The exporter needs root/CAP_BPF to read BPF maps
sudo python3 xdp_otel_exporter_simple.py ...

# Check SELinux if on RHEL9
sudo getenforce
sudo ausearch -m avc -ts recent
```

## Integration with Existing Demo

This exporter is designed to work alongside the existing scrapers:

```bash
# Terminal 1: The existing Python bpftool scraper
python3 the_existing_scraper.py

# Terminal 2: The existing libbpf scraper
./the_libbpf_scraper

# Terminal 3: New OpenTelemetry exporter
sudo python3 xdp_otel_exporter_simple.py --map-name xdp_stats_map
```

All three can read from the same BPF map simultaneously!

## Production Considerations

For production use on RHEL9, consider:

1. **TLS/Authentication**: Enable TLS in `otel-collector-config.yaml`
   ```yaml
   exporters:
     otlp:
       endpoint: collector.example.com:4317
       tls:
         cert_file: /path/to/cert.pem
         key_file: /path/to/key.pem
   ```

2. **Resource Limits**: Set appropriate CPU/memory limits
3. **High Availability**: Run multiple collector instances with load balancing
4. **Retention**: Configure Prometheus retention policies
5. **Security**: Use least-privilege service accounts

## Extending the Demo

### Add Custom Metrics
Modify the exporter to track additional statistics:

```python
# Add per-protocol counters
self.meter.create_observable_counter(
    name="xdp.tcp.packets",
    callbacks=[self._get_tcp_count],
    ...
)
```

### Add Distributed Tracing
Export trace spans for packet processing:

```python
from opentelemetry import trace
from opentelemetry.sdk.trace import TracerProvider

# Create spans for packet processing events
with tracer.start_as_current_span("packet_process"):
    # The packet handling logic
    pass
```

### Send to Cloud Backends
Configure different exporters in `otel-collector-config.yaml`:

```yaml
exporters:
  # Send to Datadog
  datadog:
    api_key: "${DD_API_KEY}"
    site: datadoghq.com
  
  # Send to New Relic
  otlp/newrelic:
    endpoint: otlp.nr-data.net:4317
    headers:
      api-key: "${NEW_RELIC_API_KEY}"
```

## Files in This Demo

- `xdp_otel_exporter_simple.py`: Main exporter using bpftool (recommended)
- `xdp_otel_exporter.py`: Alternative exporter using BCC library
- `docker-compose.yml`: Complete monitoring stack (Podman/Docker compatible)
- `otel-collector-config.yaml`: OpenTelemetry Collector configuration
- `prometheus.yml`: Prometheus scrape configuration
- `grafana-datasources.yml`: Grafana datasource provisioning
- `requirements.txt`: Python dependencies
- `setup-rhel9.sh`: Automated setup script for RHEL9
- `test-setup.sh`: Verification script
- `PODMAN-COMMANDS.md`: Podman command reference
- `PODMAN-TROUBLESHOOTING.md`: Podman troubleshooting guide

## References

- [OpenTelemetry Python SDK](https://opentelemetry.io/docs/languages/python/)
- [OpenTelemetry Collector](https://opentelemetry.io/docs/collector/)
- [RHEL9 eBPF Documentation](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/configuring_and_managing_networking/assembly_understanding-the-ebpf-features-in-rhel-9_configuring-and-managing-networking)
- [RHEL9 Podman Documentation](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/building_running_and_managing_containers/)
- [bpftool Documentation](https://man7.org/linux/man-pages/man8/bpftool.8.html)
- [Rootless Podman Guide](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)

## License

Same as the existing XDP packet counter demo.
