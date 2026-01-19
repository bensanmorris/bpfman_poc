#!/usr/bin/env python3
"""
Enhanced XDP Packet Counter OpenTelemetry Exporter

This version supports the full stats structure with protocol breakdown:
- total_packets, total_bytes
- icmp_packets, tcp_packets, udp_packets, other_packets
- ipv4_packets, ipv6_packets

Usage:
    python3 xdp_otel_exporter_enhanced.py --map-name stats_map
"""

import argparse
import time
import logging
import sys
import json
import subprocess
import struct

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
                    # Parse line like: "123: array  name stats_map  ..."
                    map_id = line.split(':')[0]
                    logger.info(f"Found map '{self.map_name}' with ID {map_id}")
                    return int(map_id)
            
            logger.error(f"Map '{self.map_name}' not found")
            logger.info("Available maps:")
            logger.info(result.stdout)
            return None
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Error running bpftool: {e}")
            return None
    
    def read_stats(self):
        """
        Read statistics from BPF map using bpftool JSON output
        
        Returns:
            dict: Full stats structure with protocol breakdown
        """
        map_id = self._find_map_id()
        if not map_id:
            return self._empty_stats()
        
        try:
            # Dump map contents as JSON
            result = subprocess.run(
                ["bpftool", "map", "dump", "id", str(map_id), "-j"],
                capture_output=True,
                text=True,
                check=True
            )
            
            # Parse JSON output
            import json
            data = json.loads(result.stdout)
            
            # bpftool returns an array with one entry for our map
            # The entry has 'formatted' which contains the parsed values
            if isinstance(data, list) and len(data) > 0:
                entry = data[0]
                
                # Use 'formatted' field which has the parsed values
                if isinstance(entry, dict) and 'formatted' in entry:
                    formatted = entry['formatted']
                    if 'value' in formatted:
                        value = formatted['value']
                        
                        # value is now a dict with our field names
                        return {
                            'total_packets': value['total_packets'],
                            'total_bytes': value['total_bytes'],
                            'icmp_packets': value['icmp_packets'],
                            'tcp_packets': value['tcp_packets'],
                            'udp_packets': value['udp_packets'],
                            'other_packets': value['other_packets'],
                            'ipv4_packets': value['ipv4_packets'],
                            'ipv6_packets': value['ipv6_packets']
                        }
            
            logger.warning(f"Unexpected data structure. Type: {type(data)}, Data: {data}")
            return self._empty_stats()
            
        except subprocess.CalledProcessError as e:
            logger.error(f"Error reading map: {e}")
            return self._empty_stats()
        except json.JSONDecodeError as e:
            logger.error(f"Error parsing JSON: {e}")
            logger.debug(f"Output was: {result.stdout}")
            return self._empty_stats()
        except Exception as e:
            logger.error(f"Unexpected error: {e}")
            return self._empty_stats()
    
    def _empty_stats(self):
        """Return empty stats structure"""
        return {
            'total_packets': 0,
            'total_bytes': 0,
            'icmp_packets': 0,
            'tcp_packets': 0,
            'udp_packets': 0,
            'other_packets': 0,
            'ipv4_packets': 0,
            'ipv6_packets': 0
        }


class XDPOtelExporter:
    """Export XDP statistics to OpenTelemetry with full protocol breakdown"""
    
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
        
        # Create metrics for all stats
        # Total counters
        self.meter.create_observable_counter(
            name="xdp.packets.total",
            callbacks=[self._get_total_packets],
            unit="packets",
            description="Total packets processed by XDP"
        )
        
        self.meter.create_observable_counter(
            name="xdp.bytes.total",
            callbacks=[self._get_total_bytes],
            unit="bytes",
            description="Total bytes processed by XDP"
        )
        
        # Protocol counters
        self.meter.create_observable_counter(
            name="xdp.packets.icmp",
            callbacks=[self._get_icmp_packets],
            unit="packets",
            description="ICMP packets"
        )
        
        self.meter.create_observable_counter(
            name="xdp.packets.tcp",
            callbacks=[self._get_tcp_packets],
            unit="packets",
            description="TCP packets"
        )
        
        self.meter.create_observable_counter(
            name="xdp.packets.udp",
            callbacks=[self._get_udp_packets],
            unit="packets",
            description="UDP packets"
        )
        
        self.meter.create_observable_counter(
            name="xdp.packets.other",
            callbacks=[self._get_other_packets],
            unit="packets",
            description="Other protocol packets"
        )
        
        # IP version counters
        self.meter.create_observable_counter(
            name="xdp.packets.ipv4",
            callbacks=[self._get_ipv4_packets],
            unit="packets",
            description="IPv4 packets"
        )
        
        self.meter.create_observable_counter(
            name="xdp.packets.ipv6",
            callbacks=[self._get_ipv6_packets],
            unit="packets",
            description="IPv6 packets"
        )
        
        # Rate gauge
        self.meter.create_observable_gauge(
            name="xdp.packets.rate",
            callbacks=[self._get_packet_rate],
            unit="packets/sec",
            description="Packet processing rate"
        )
        
        # State tracking
        self.current_stats = self.stats_reader._empty_stats()
        self.prev_packets = 0
        self.prev_time = time.time()
        self.current_rate = 0.0
        
        logger.info("Enhanced XDP OpenTelemetry exporter initialized")
        logger.info(f"  OTLP endpoint: {otel_endpoint}")
        logger.info(f"  Export interval: {export_interval}s")
        logger.info("  Exporting metrics:")
        logger.info("    - xdp.packets.total, xdp.bytes.total")
        logger.info("    - xdp.packets.{icmp,tcp,udp,other}")
        logger.info("    - xdp.packets.{ipv4,ipv6}")
        logger.info("    - xdp.packets.rate")
    
    def _update_stats(self):
        """Read latest stats from BPF map"""
        self.current_stats = self.stats_reader.read_stats()
        
        # Calculate rate
        current_time = time.time()
        time_delta = current_time - self.prev_time
        
        if time_delta > 0:
            packet_delta = self.current_stats['total_packets'] - self.prev_packets
            self.current_rate = packet_delta / time_delta
        else:
            self.current_rate = 0.0
        
        self.prev_packets = self.current_stats['total_packets']
        self.prev_time = current_time
    
    # Callback functions for metrics
    def _get_total_packets(self, options):
        self._update_stats()
        yield metrics.Observation(self.current_stats['total_packets'])
    
    def _get_total_bytes(self, options):
        yield metrics.Observation(self.current_stats['total_bytes'])
    
    def _get_icmp_packets(self, options):
        yield metrics.Observation(self.current_stats['icmp_packets'])
    
    def _get_tcp_packets(self, options):
        yield metrics.Observation(self.current_stats['tcp_packets'])
    
    def _get_udp_packets(self, options):
        yield metrics.Observation(self.current_stats['udp_packets'])
    
    def _get_other_packets(self, options):
        yield metrics.Observation(self.current_stats['other_packets'])
    
    def _get_ipv4_packets(self, options):
        yield metrics.Observation(self.current_stats['ipv4_packets'])
    
    def _get_ipv6_packets(self, options):
        yield metrics.Observation(self.current_stats['ipv6_packets'])
    
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
                s = self.current_stats
                logger.info(
                    f"Total: {s['total_packets']:,} pkts, {s['total_bytes']:,} bytes | "
                    f"IPv4: {s['ipv4_packets']:,}, IPv6: {s['ipv6_packets']:,} | "
                    f"TCP: {s['tcp_packets']:,}, UDP: {s['udp_packets']:,}, "
                    f"ICMP: {s['icmp_packets']:,}, Other: {s['other_packets']:,} | "
                    f"Rate: {self.current_rate:.2f} pps"
                )
        except KeyboardInterrupt:
            logger.info("\nShutting down...")
            sys.exit(0)


def main():
    parser = argparse.ArgumentParser(
        description="Export XDP packet statistics to OpenTelemetry (Enhanced with protocol breakdown)"
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
    
    # Create stats reader
    reader = BpftoolStatsReader(
        map_id=args.map_id,
        map_name=args.map_name
    )
    
    # Test reading once
    logger.info("Testing map read...")
    test_stats = reader.read_stats()
    logger.info(f"Current stats: {test_stats}")
    
    if test_stats['total_packets'] == 0 and test_stats['total_bytes'] == 0:
        logger.warning("Map appears empty or not found. Make sure your XDP program is loaded.")
        logger.info("Available maps:")
        subprocess.run(["bpftool", "map", "list"])
    
    # Create and run exporter
    exporter = XDPOtelExporter(
        stats_reader=reader,
        otel_endpoint=args.otel_endpoint,
        export_interval=args.interval
    )
    exporter.run()


if __name__ == "__main__":
    main()
