#!/usr/bin/env python3
"""
XDP Packet Counter OpenTelemetry Exporter

This script reads packet statistics from the XDP BPF map and exports
them to an OpenTelemetry backend (Prometheus, Jaeger, etc.)

Usage:
    python3 xdp_otel_exporter.py --map-path /sys/fs/bpf/stats_map --otel-endpoint localhost:4317
"""

import argparse
import time
import logging
import sys
from pathlib import Path

from bcc import BPF
from opentelemetry import metrics
from opentelemetry.sdk.metrics import MeterProvider
from opentelemetry.sdk.metrics.export import PeriodicExportingMetricReader
from opentelemetry.exporter.otlp.proto.grpc.metric_exporter import OTLPMetricExporter
from opentelemetry.sdk.resources import Resource

logging.basicConfig(
    level=logging.INFO,
    format='%(asctime)s - %(name)s - %(levelname)s - %(message)s'
)
logger = logging.getLogger(__name__)


class XDPStatsExporter:
    """Exports XDP packet statistics to OpenTelemetry"""
    
    def __init__(self, map_path: str, otel_endpoint: str, export_interval: int = 10):
        """
        Initialize the exporter
        
        Args:
            map_path: Path to the pinned BPF map (e.g., /sys/fs/bpf/stats_map)
            otel_endpoint: OpenTelemetry collector endpoint (e.g., localhost:4317)
            export_interval: How often to export metrics (seconds)
        """
        self.map_path = map_path
        self.export_interval = export_interval
        
        # Initialize OpenTelemetry
        resource = Resource.create({
            "service.name": "xdp-packet-counter",
            "deployment.environment": "demo",
        })
        
        # Configure OTLP exporter
        otlp_exporter = OTLPMetricExporter(
            endpoint=otel_endpoint,
            insecure=True  # Use insecure for demo; enable TLS in production
        )
        
        # Create metric reader with periodic export
        reader = PeriodicExportingMetricReader(
            otlp_exporter,
            export_interval_millis=export_interval * 1000
        )
        
        # Set up MeterProvider
        provider = MeterProvider(resource=resource, metric_readers=[reader])
        metrics.set_meter_provider(provider)
        
        # Create meter
        self.meter = metrics.get_meter(__name__)
        
        # Create observable counters for packet stats
        self.meter.create_observable_counter(
            name="xdp.packets.total",
            callbacks=[self._get_packet_count],
            unit="packets",
            description="Total number of packets processed by XDP"
        )
        
        self.meter.create_observable_counter(
            name="xdp.bytes.total", 
            callbacks=[self._get_byte_count],
            unit="bytes",
            description="Total bytes processed by XDP"
        )
        
        self.meter.create_observable_gauge(
            name="xdp.packets.rate",
            callbacks=[self._get_packet_rate],
            unit="packets/sec",
            description="Packet processing rate"
        )
        
        # Track previous values for rate calculation
        self.prev_packets = 0
        self.prev_bytes = 0
        self.prev_time = time.time()
        self.current_stats = {"packets": 0, "bytes": 0, "rate": 0.0}
        
        logger.info(f"Initialized XDP OpenTelemetry exporter")
        logger.info(f"  Map path: {map_path}")
        logger.info(f"  OTLP endpoint: {otel_endpoint}")
        logger.info(f"  Export interval: {export_interval}s")
    
    def _read_bpf_map(self):
        """Read statistics from the BPF map"""
        try:
            # Load the pinned map
            # This assumes the map is pinned at the specified path
            # The map structure should match the XDP program
            b = BPF()
            stats_map = b.get_table("stats_map", pinned_path=self.map_path)
            
            # Read stats (key=0 for single global counter)
            key = stats_map.Key(0)
            try:
                leaf = stats_map[key]
                return {
                    "packets": leaf.rx_packets,
                    "bytes": leaf.rx_bytes
                }
            except KeyError:
                logger.warning("No data in BPF map yet")
                return {"packets": 0, "bytes": 0}
                
        except Exception as e:
            logger.error(f"Error reading BPF map: {e}")
            return {"packets": 0, "bytes": 0}
    
    def _update_stats(self):
        """Update current statistics from BPF map"""
        stats = self._read_bpf_map()
        
        # Calculate rate
        current_time = time.time()
        time_delta = current_time - self.prev_time
        
        if time_delta > 0:
            packet_delta = stats["packets"] - self.prev_packets
            rate = packet_delta / time_delta
        else:
            rate = 0.0
        
        self.current_stats = {
            "packets": stats["packets"],
            "bytes": stats["bytes"],
            "rate": rate
        }
        
        self.prev_packets = stats["packets"]
        self.prev_bytes = stats["bytes"]
        self.prev_time = current_time
    
    def _get_packet_count(self, options):
        """Callback for packet counter metric"""
        self._update_stats()
        yield metrics.Observation(self.current_stats["packets"])
    
    def _get_byte_count(self, options):
        """Callback for byte counter metric"""
        yield metrics.Observation(self.current_stats["bytes"])
    
    def _get_packet_rate(self, options):
        """Callback for packet rate gauge"""
        yield metrics.Observation(self.current_stats["rate"])
    
    def run(self):
        """Run the exporter (blocking)"""
        logger.info("Starting XDP OpenTelemetry exporter...")
        logger.info("Press Ctrl+C to stop")
        
        try:
            while True:
                time.sleep(1)
                # Metrics are automatically exported by PeriodicExportingMetricReader
                
        except KeyboardInterrupt:
            logger.info("Shutting down...")
            sys.exit(0)


def main():
    parser = argparse.ArgumentParser(
        description="Export XDP packet statistics to OpenTelemetry"
    )
    parser.add_argument(
        "--map-path",
        default="/sys/fs/bpf/stats_map",
        help="Path to pinned BPF map (default: /sys/fs/bpf/stats_map)"
    )
    parser.add_argument(
        "--otel-endpoint",
        default="localhost:4317",
        help="OpenTelemetry collector gRPC endpoint (default: localhost:4317)"
    )
    parser.add_argument(
        "--interval",
        type=int,
        default=10,
        help="Export interval in seconds (default: 10)"
    )
    parser.add_argument(
        "--debug",
        action="store_true",
        help="Enable debug logging"
    )
    
    args = parser.parse_args()
    
    if args.debug:
        logging.getLogger().setLevel(logging.DEBUG)
    
    # Verify map exists
    if not Path(args.map_path).exists():
        logger.error(f"BPF map not found at {args.map_path}")
        logger.error("Make sure the XDP program is running and the map is pinned")
        sys.exit(1)
    
    # Create and run exporter
    exporter = XDPStatsExporter(
        map_path=args.map_path,
        otel_endpoint=args.otel_endpoint,
        export_interval=args.interval
    )
    exporter.run()


if __name__ == "__main__":
    main()
