# XDP → OpenTelemetry Architecture Diagram

## Complete System Overview

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              RHEL9 Host System                               │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                               │
│  ┌─────────────────────────────────────────────────────────────────────┐   │
│  │                         Kernel Space                                 │   │
│  │                                                                       │   │
│  │  ┌──────────────────────────────────────────────────────────────┐  │   │
│  │  │  XDP Program (loaded via libxdp)                             │  │   │
│  │  │  - Attached to eth0                                          │  │   │
│  │  │  - Runs at earliest packet receive point                     │  │   │
│  │  │  - Counts packets and bytes                                  │  │   │
│  │  └────────────────────────┬─────────────────────────────────────┘  │   │
│  │                            │                                         │   │
│  │                            ↓                                         │   │
│  │  ┌──────────────────────────────────────────────────────────────┐  │   │
│  │  │  BPF Maps (pinned at /sys/fs/bpf/)                           │  │   │
│  │  │  ┌────────────────────────────────────────────────────────┐ │  │   │
│  │  │  │ xdp_stats_map (hash map)                               │ │  │   │
│  │  │  │   Key: 0 (global counter)                              │ │  │   │
│  │  │  │   Value: {                                             │ │  │   │
│  │  │  │     rx_packets: uint64                                 │ │  │   │
│  │  │  │     rx_bytes: uint64                                   │ │  │   │
│  │  │  │   }                                                     │ │  │   │
│  │  │  └────────────────────────────────────────────────────────┘ │  │   │
│  │  └────────────────────────┬─────────────────────────────────────┘  │   │
│  └─────────────────────────────┼──────────────────────────────────────┘   │
│                                │                                            │
│  ══════════════════════════════╪════════════════════════════════════════   │
│                                │                                            │
│  ┌─────────────────────────────┴────────────────────────────────────────┐ │
│  │                         User Space                                    │ │
│  │                                                                        │ │
│  │  The Existing Scrapers (keep working!)                              │ │
│  │  ┌───────────────────┐  ┌───────────────────┐                       │ │
│  │  │ Python bpftool    │  │ libbpf C Program  │                       │ │
│  │  │ Scraper           │  │ Scraper           │                       │ │
│  │  │ • Calls bpftool   │  │ • Uses libbpf     │                       │ │
│  │  │ • Outputs to file │  │ • Direct map read │                       │ │
│  │  └───────────────────┘  └───────────────────┘                       │ │
│  │                                                                        │ │
│  │  NEW: OpenTelemetry Exporter                                         │ │
│  │  ┌──────────────────────────────────────────────────────────────┐   │ │
│  │  │ xdp_otel_exporter_simple.py                                  │   │ │
│  │  │ • Reads BPF map via bpftool                                  │   │ │
│  │  │ • Calculates rates (packets/sec, bytes/sec)                  │   │ │
│  │  │ • Exports via OpenTelemetry SDK                              │   │ │
│  │  │ • Uses OTLP/gRPC protocol                                    │   │ │
│  │  └──────────────────────────┬───────────────────────────────────┘   │ │
│  │                              │                                        │ │
│  │                              │ OTLP/gRPC (localhost:4317)            │ │
│  │                              │                                        │ │
│  └──────────────────────────────┼────────────────────────────────────────┘ │
│                                 │                                            │
│  ┌──────────────────────────────┴────────────────────────────────────────┐ │
│  │                    Podman Containers (rootless)                        │ │
│  │                                                                         │ │
│  │  ┌────────────────────────────────────────────────────────────────┐  │ │
│  │  │ Container: otel-collector                                       │  │ │
│  │  │ Image: otel/opentelemetry-collector:latest                      │  │ │
│  │  │                                                                  │  │ │
│  │  │ Receivers:                      Exporters:                      │  │ │
│  │  │ • OTLP gRPC (:4317) ────────→ • Prometheus (:8889)            │  │ │
│  │  │ • OTLP HTTP (:4318)            • Jaeger (:14250)               │  │ │
│  │  │                                 • Debug logs                    │  │ │
│  │  │                                                                  │  │ │
│  │  │ Processors:                                                      │  │ │
│  │  │ • Batch (10s, 1024 records)                                     │  │ │
│  │  │ • Memory limiter (512MB)                                        │  │ │
│  │  │ • Resource attributes                                            │  │ │
│  │  └──────────────────────┬───────────────────┬───────────────────────┘  │ │
│  │                         │                   │                           │ │
│  │                         │ Prometheus        │ OTLP                      │ │
│  │                         │ metrics           │ traces                    │ │
│  │                         │                   │                           │ │
│  │  ┌──────────────────────┴──────┐  ┌────────┴─────────────────────┐    │ │
│  │  │ Container: prometheus        │  │ Container: jaeger            │    │ │
│  │  │ • Scrapes :8889 every 15s   │  │ • Receives traces            │    │ │
│  │  │ • Stores time-series data   │  │ • UI at :16686               │    │ │
│  │  │ • Retention: 15 days         │  │ • gRPC at :14250             │    │ │
│  │  │ • Query UI at :9090          │  └──────────────────────────────┘    │ │
│  │  └──────────────┬───────────────┘                                       │ │
│  │                 │                                                        │ │
│  │                 │ PromQL                                                │ │
│  │                 │                                                        │ │
│  │  ┌──────────────┴───────────────────────────────────────────────────┐  │ │
│  │  │ Container: grafana                                                │  │ │
│  │  │ • Dashboard UI at :3000                                           │  │ │
│  │  │ • Pre-configured Prometheus datasource                           │  │ │
│  │  │ • Query: xdp_xdp_packets_total                                   │  │ │
│  │  │ • Visualize: rates, totals, graphs                               │  │ │
│  │  └───────────────────────────────────────────────────────────────────┘  │ │
│  │                                                                         │ │
│  │  Network: monitoring (bridge)                                          │ │
│  │  Volumes: prometheus-data, grafana-data (persistent)                  │ │
│  └─────────────────────────────────────────────────────────────────────────┘ │
│                                                                               │
└─────────────────────────────────────────────────────────────────────────────┘

═══════════════════════════════════════════════════════════════════════════════

External Access:
  http://localhost:3000  → Grafana (admin/admin)
  http://localhost:9090  → Prometheus
  http://localhost:16686 → Jaeger UI
  localhost:4317         → OpenTelemetry gRPC (for exporter)
  localhost:8889         → Prometheus metrics (scrape endpoint)

═══════════════════════════════════════════════════════════════════════════════
```

## Data Flow

```
Packets → XDP Program → BPF Maps → [Multiple readers in parallel]
                                    │
                                    ├─→ Python bpftool scraper → stdout/file
                                    │
                                    ├─→ libbpf C scraper → stdout/file
                                    │
                                    └─→ OpenTelemetry exporter → OTel Collector
                                                                  │
                                                                  ├→ Prometheus → Grafana
                                                                  │
                                                                  └→ Jaeger (traces)
```

## Metric Flow Detail

```
BPF Map Stats                  OpenTelemetry Metrics
┌──────────────┐              ┌─────────────────────────────┐
│ rx_packets:  │              │ xdp.packets.total          │
│   1,234,567  │ ─────────→  │   Value: 1,234,567         │
│              │              │   Type: Counter             │
│ rx_bytes:    │              │   Unit: packets             │
│  987,654,321 │ ─────────→  │                            │
└──────────────┘              │ xdp.bytes.total            │
                               │   Value: 987,654,321       │
      ↓                        │   Type: Counter             │
  Calculate rate              │   Unit: bytes               │
      ↓                        │                            │
┌──────────────┐              │ xdp.packets.rate           │
│ Current:     │              │   Value: 12,345.67         │
│  12,345 pps  │ ─────────→  │   Type: Gauge              │
└──────────────┘              │   Unit: packets/sec        │
                               └─────────────────────────────┘
                                         ↓
                                   OTLP/gRPC
                                         ↓
                               ┌─────────────────────┐
                               │ OTel Collector      │
                               │ • Batch             │
                               │ • Resource attrs    │
                               │ • Memory limit      │
                               └─────────────────────┘
                                         ↓
                               ┌─────────────────────┐
                               │ Prometheus Format   │
                               │ xdp_xdp_packets_    │
                               │ total{env="demo"}   │
                               └─────────────────────┘
                                         ↓
                               ┌─────────────────────┐
                               │ Prometheus TSDB     │
                               │ • 15 day retention  │
                               │ • 15s scrape        │
                               └─────────────────────┘
                                         ↓
                               ┌─────────────────────┐
                               │ Grafana Dashboard   │
                               │ • Rate graphs       │
                               │ • Total counters    │
                               │ • Alerts            │
                               └─────────────────────┘
```

## Port Map

```
RHEL9 Host
├─ 4317  → OTel Collector (gRPC)
├─ 4318  → OTel Collector (HTTP)
├─ 8889  → OTel Collector (Prometheus export)
├─ 9090  → Prometheus (Query UI & API)
├─ 3000  → Grafana (Dashboard UI)
├─ 16686 → Jaeger (Trace UI)
└─ 14250 → Jaeger (gRPC collector)

All bound to localhost (127.0.0.1) by default
```

## Process Tree

```
systemd
├─ podman pod [monitoring]
│  ├─ otel-collector (UID: user)
│  ├─ prometheus (UID: user)
│  ├─ grafana (UID: user)
│  └─ jaeger (UID: user)
│
└─ python3 xdp_otel_exporter_simple.py (UID: root/CAP_BPF)
```

## File System Layout

```
/home/user/xdp-otel-demo/
├── *.py                           # Python exporters
├── *.yaml, *.yml                  # Container configs
├── *.sh                           # Setup scripts
└── *.md                           # Documentation

/sys/fs/bpf/
└── xdp_stats_map                  # Pinned BPF map

Podman volumes:
~/.local/share/containers/storage/volumes/
├── prometheus-data/               # Time-series DB
└── grafana-data/                  # Dashboards, users
```

## Network Topology

```
Container Network: monitoring (10.89.0.0/16)
┌─────────────────────────────────────────────────────────┐
│                                                           │
│  10.89.0.2    10.89.0.3     10.89.0.4      10.89.0.5    │
│  ┌────────┐  ┌──────────┐  ┌─────────┐  ┌─────────┐   │
│  │  OTel  │  │Prometheus│  │ Grafana │  │ Jaeger  │   │
│  │Collect │  └──────────┘  └─────────┘  └─────────┘   │
│  └────────┘                                             │
│      ↑                                                   │
└──────┼───────────────────────────────────────────────────┘
       │
       │ Port mapping
       │
┌──────┼───────────────────────────────────────────────────┐
│  Host Network (eth0: 192.168.1.100)                      │
│      │                                                    │
│  ┌───┴────────────────┐                                 │
│  │ Python Exporter    │                                 │
│  │ localhost:4317 ────┘                                 │
│  └────────────────────                                  │
└─────────────────────────────────────────────────────────┘
```
