#!/usr/bin/env python3
# Read and display XDP packet counter statistics
# This properly parses the BPF map structure

import subprocess
import struct
import sys
import time

# ANSI colors
GREEN = '\033[0;32m'
YELLOW = '\033[1;33m'
RED = '\033[0;31m'
BLUE = '\033[0;34m'
CYAN = '\033[0;36m'
BOLD = '\033[1m'
NC = '\033[0m'

def find_stats_map():
    """Find the stats_map ID"""
    try:
        result = subprocess.run(['sudo', 'bpftool', 'map', 'show'], 
                              capture_output=True, text=True, check=True)
        for line in result.stdout.split('\n'):
            if 'stats_map' in line:
                map_id = line.split(':')[0]
                return map_id.strip()
    except subprocess.CalledProcessError:
        return None
    return None

def read_map_data(map_id):
    """Read raw bytes from BPF map"""
    try:
        # Get map dump in hex format
        result = subprocess.run(['sudo', 'bpftool', 'map', 'dump', 'id', map_id],
                              capture_output=True, text=True, check=True)
        
        # Parse the hex output
        # Format: "value: XX XX XX XX ..."
        for line in result.stdout.split('\n'):
            if 'value:' in line:
                hex_str = line.split('value:')[1].strip()
                # Remove spaces and convert to bytes
                hex_bytes = hex_str.replace(' ', '')
                # Convert hex string to bytes
                data_bytes = bytes.fromhex(hex_bytes)
                return data_bytes
    except (subprocess.CalledProcessError, ValueError, IndexError) as e:
        print(f"{RED}Error reading map: {e}{NC}", file=sys.stderr)
    return None

def parse_stats(data_bytes):
    """Parse the pkt_stats structure from bytes"""
    # Structure: 8 x __u64 (little-endian)
    # total_packets, total_bytes, icmp, tcp, udp, other, ipv4, ipv6
    
    if len(data_bytes) < 64:  # 8 * 8 bytes
        return None
    
    try:
        stats = struct.unpack('<QQQQQQQQ', data_bytes[:64])
        return {
            'total_packets': stats[0],
            'total_bytes': stats[1],
            'icmp_packets': stats[2],
            'tcp_packets': stats[3],
            'udp_packets': stats[4],
            'other_packets': stats[5],
            'ipv4_packets': stats[6],
            'ipv6_packets': stats[7],
        }
    except struct.error as e:
        print(f"{RED}Error parsing stats: {e}{NC}", file=sys.stderr)
        return None

def format_bytes(bytes_val):
    """Format bytes in human-readable form"""
    for unit in ['B', 'KB', 'MB', 'GB']:
        if bytes_val < 1024.0:
            return f"{bytes_val:.2f} {unit}"
        bytes_val /= 1024.0
    return f"{bytes_val:.2f} TB"

def display_stats(stats):
    """Display statistics in a nice format"""
    print(f"{CYAN}╔════════════════════════════════════════════╗{NC}")
    print(f"{CYAN}║       XDP Packet Counter Statistics       ║{NC}")
    print(f"{CYAN}╚════════════════════════════════════════════╝{NC}")
    print()
    
    print(f"{BOLD}Overall Statistics:{NC}")
    print(f"  {GREEN}Total Packets:{NC}  {stats['total_packets']:,}")
    print(f"  {GREEN}Total Bytes:{NC}    {format_bytes(stats['total_bytes'])} ({stats['total_bytes']:,} bytes)")
    print()
    
    print(f"{BOLD}By Protocol:{NC}")
    print(f"  {BLUE}ICMP:{NC}  {stats['icmp_packets']:,}")
    print(f"  {BLUE}TCP:{NC}   {stats['tcp_packets']:,}")
    print(f"  {BLUE}UDP:{NC}   {stats['udp_packets']:,}")
    print(f"  {BLUE}Other:{NC} {stats['other_packets']:,}")
    print()
    
    print(f"{BOLD}By IP Version:{NC}")
    print(f"  {BLUE}IPv4:{NC} {stats['ipv4_packets']:,}")
    print(f"  {BLUE}IPv6:{NC} {stats['ipv6_packets']:,}")
    print()
    
    # Calculate percentages if there are packets
    total = stats['total_packets']
    if total > 0:
        print(f"{BOLD}Protocol Distribution:{NC}")
        print(f"  ICMP: {stats['icmp_packets']/total*100:5.1f}%")
        print(f"  TCP:  {stats['tcp_packets']/total*100:5.1f}%")
        print(f"  UDP:  {stats['udp_packets']/total*100:5.1f}%")
        print(f"  Other: {stats['other_packets']/total*100:5.1f}%")
        print()

def main():
    # Find the map
    map_id = find_stats_map()
    if not map_id:
        print(f"{RED}✗ stats_map not found{NC}")
        print("Is the XDP program loaded?")
        print("Run: ./02-load.sh")
        sys.exit(1)
    
    # Read map data
    data = read_map_data(map_id)
    if not data:
        print(f"{YELLOW}⚠ Could not read map data{NC}")
        sys.exit(1)
    
    # Parse statistics
    stats = parse_stats(data)
    if not stats:
        print(f"{RED}✗ Could not parse statistics{NC}")
        sys.exit(1)
    
    # Check if we have any data
    if stats['total_packets'] == 0:
        print(f"{YELLOW}⚠ No packets counted yet{NC}")
        print()
        print("Generate some traffic:")
        print("  ping -c 5 8.8.8.8")
        print("  curl -s http://example.com > /dev/null")
        sys.exit(0)
    
    # Display the statistics
    display_stats(stats)
    
    print(f"{YELLOW}Tip:{NC} For real-time updates:")
    print(f"  watch -n 1 {sys.argv[0]}")
    print()

if __name__ == '__main__':
    try:
        main()
    except KeyboardInterrupt:
        print(f"\n{YELLOW}Interrupted{NC}")
        sys.exit(0)
