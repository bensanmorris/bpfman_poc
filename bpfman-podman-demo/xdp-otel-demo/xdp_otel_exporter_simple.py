#!/usr/bin/env python3
"""
Simple XDP Packet Counter OpenTelemetry Exporter using bpftool

This version uses bpftool to read BPF maps, avoiding the BCC dependency.
This is more lightweight and follows the pattern of the existing bpftool scraper.

Usage:
    python3 xdp_otel_exporter_simple.py --map-id 123 --otel-endpoint localhost:4317
"""

import argparse
import time
import logging
import sys
import json
import subprocess

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


class BpftoolStatsReader:
    """Read XDP statistics using bpftool"""
    
    def __init__(self, map_id=None, map_name=None):
        """
        Initialize reader
        
        Args:
            map_id: BPF map ID (from bpftool map list)
            map_name: BPF map name (alternative to map_id)
        """
        self.map_id = map_id
        self.map_name = map_name
        
        if not map_id and not map_name:
            raise ValueError("Must provide either map_id or map_name")
    
    def _find_map_id(self):
        """Find map ID by name if not provided"""
        if self.map_id:
            return self.map_id
        
        try:
            result = subprocess.run(
                ["bpftool", "map", "list"],
                capture_output=True,
                text=True,
                check=True
            )
            
            for line in result.stdout.split('\n'):
                if self.map_name in line:
                    # Parse line like: "123: hash  name stats_map  ..."
                    map_id = line.split(':')[0]
                    logger.info(f"Found map '{self.map_name}' with ID {map_id}")
                    return int(map_id)
            
            logger.error(f"Map '{self.map_name}' not found")
            return None
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Error running bpftool: {e}")
            return None
    
    def read_stats(self):
        """
        Read statistics from BPF map using bpftool
        
        Returns:
            dict: {"packets": int, "bytes": int}
        """
        map_id = self._find_map_id()
        if not map_id:
            return {"packets": 0, "bytes": 0}
        
        try:
            # Dump map contents
            result = subprocess.run(
                ["bpftool", "map", "dump", "id", str(map_id)],
                capture_output=True,
                text=True,
                check=True
            )
            
            # Parse output
            # bpftool output format varies, but typically JSON-like
            # Example: key: 00 00 00 00  value: 10 00 00 00 00 00 00 00 20 00 00 00 00 00 00 00
            
            packets = 0
            bytes_count = 0
            
            for line in result.stdout.split('\n'):
                if 'value:' in line:
                    # Extract hex bytes from value line
                    value_part = line.split('value:')[1].strip()
                    hex_bytes = value_part.replace(' ', '')
                    
                    # Assuming first 8 bytes are packets, next 8 bytes are bytes
                    # (Adjust based on the actual struct layout)
                    if len(hex_bytes) >= 32:  # 16 bytes = 32 hex chars
                        # Parse as little-endian uint64
                        packets_hex = hex_bytes[:16]
                        bytes_hex = hex_bytes[16:32]
                        
                        # Convert hex to int (reverse for little-endian)
                        packets = int.from_bytes(
                            bytes.fromhex(packets_hex), 
                            byteorder='little'
                        )
                        bytes_count = int.from_bytes(
                            bytes.fromhex(bytes_hex),
                            byteorder='little'
                        )
            
            return {"packets": packets, "bytes": bytes_count}
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Error reading map: {e}")
            return {"packets": 0, "bytes": 0}
        except Exception as e:
            logger.error(f"Error parsing map data: {e}")
            return {"packets": 0, "bytes": 0}


class XDPOtelExporter:
    """Export XDP statistics to OpenTelemetry"""
    
    def __init__(self, stats_reader, otel_endpoint: str, export_interval: int = 10):
        self.stats_reader = stats_reader
        self.export_interval = export_interval
        
        # Initialize OpenTelemetry
        resource = Resource.create({
            "service.name": "xdp-packet-counter",
            "deployment.environment": "demo",
        })
        
        otlp_exporter = OTLPMetricExporter(
            endpoint=otel_endpoint,
            insecure=True
        )
        
        reader = PeriodicExportingMetricReader(
            otlp_exporter,
            export_interval_millis=export_interval * 1000
        )
        
        provider = MeterProvider(resource=resource, metric_readers=[reader])
        metrics.set_meter_provider(provider)
        
        self.meter = metrics.get_meter(__name__)
        
        # Create metrics
        self.meter.create_observable_counter(
            name="xdp.packets.total",
            callbacks=[self._get_packet_count],
            unit="packets",
            description="Total packets processed by XDP"
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
        
        # State tracking
        self.current_stats = {"packets": 0, "bytes": 0}
        self.prev_packets = 0
        self.prev_time = time.time()
        self.current_rate = 0.0

        logger.info("XDP OpenTelemetry exporter initialized")
        logger.info(f"  OTLP endpoint: {otel_endpoint}")
        logger.info(f"  Export interval: {export_interval}s")
    
    def _update_stats(self):
        """Read latest stats from BPF map"""
        self.current_stats = self.stats_reader.read_stats()
        
        # Calculate rate
        current_time = time.time()
        time_delta = current_time - self.prev_time
        
        if time_delta > 0:
            packet_delta = self.current_stats["packets"] - self.prev_packets
            self.current_rate = packet_delta / time_delta
        else:
            self.current_rate = 0.0
        
        self.prev_packets = self.current_stats["packets"]
        self.prev_time = current_time
    
    def _get_packet_count(self, options):
        self._update_stats()
        yield metrics.Observation(self.current_stats["packets"])
    
    def _get_byte_count(self, options):
        yield metrics.Observation(self.current_stats["bytes"])
    
    def _get_packet_rate(self, options):
        yield metrics.Observation(self.current_rate)
    
    def run(self):
        """Run the exporter"""
        logger.info("XDP OpenTelemetry exporter running...")
        logger.info("Press Ctrl+C to stop")
        
        try:
            while True:
                time.sleep(1)
                # Display current stats to console
                if hasattr(self, 'current_stats'):
                    logger.info(
                        f"Stats - Packets: {self.current_stats['packets']:,}, "
                        f"Bytes: {self.current_stats['bytes']:,}, "
                        f"Rate: {self.current_rate:.2f} pkt/s"
                    )
        except KeyboardInterrupt:
            logger.info("\nShutting down...")
            sys.exit(0)


def main():
    parser = argparse.ArgumentParser(
        description="Export XDP packet statistics to OpenTelemetry using bpftool"
    )
    parser.add_argument(
        "--map-id",
        type=int,
        help="BPF map ID (from 'bpftool map list')"
    )
    parser.add_argument(
        "--map-name",
        default="stats_map",
        help="BPF map name (default: stats_map)"
    )
    parser.add_argument(
        "--otel-endpoint",
        default="localhost:4317",
        help="OpenTelemetry collector endpoint (default: localhost:4317)"
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
    
    # Create stats reader
    reader = BpftoolStatsReader(
        map_id=args.map_id,
        map_name=args.map_name
    )
    
    # Create and run exporter
    exporter = XDPOtelExporter(
        stats_reader=reader,
        otel_endpoint=args.otel_endpoint,
        export_interval=args.interval
    )
    exporter.run()


if __name__ == "__main__":
    main()
