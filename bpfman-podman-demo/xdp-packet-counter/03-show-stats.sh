#!/bin/bash
# Show XDP packet counter statistics

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m'

# Clear screen for clean output (optional - comment out if not wanted)
# clear

echo -e "${CYAN}╔════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║       XDP Packet Counter Statistics       ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════╝${NC}"
echo ""

# Check if map exists
if ! sudo bpftool map show | grep -q stats_map; then
    echo -e "${RED}✗ stats_map not found${NC}"
    echo "Is the XDP program loaded?"
    echo "Run: ./02-load.sh"
    exit 1
fi

# Get map ID
STATS_MAP_ID=$(sudo bpftool map show | grep stats_map | grep -oP '^\d+' | head -1)

if [ -z "$STATS_MAP_ID" ]; then
    echo -e "${RED}✗ Could not find stats_map ID${NC}"
    exit 1
fi

echo -e "${BLUE}Reading from BPF map ID: $STATS_MAP_ID${NC}"
echo ""

# Dump the map (key 0 contains our stats)
RAW_OUTPUT=$(sudo bpftool map dump id $STATS_MAP_ID 2>/dev/null)

if [ -z "$RAW_OUTPUT" ]; then
    echo -e "${YELLOW}⚠ Map is empty or not initialized yet${NC}"
    echo "Generate some traffic to see statistics:"
    echo "  ping -c 5 8.8.8.8"
    exit 0
fi

# Parse the output
# The map dump format is:
# key: 00 00 00 00  value: XX XX XX XX ... (8 __u64 values)
# We need to extract and decode the values

echo -e "${BOLD}Packet Statistics:${NC}"
echo "─────────────────────────────────────────────"

# Extract value bytes and parse them
# This is a simplified parser - bpftool outputs in hex format
VALUE_HEX=$(echo "$RAW_OUTPUT" | grep "value:" | sed 's/.*value: //' | tr -d ' ')

if [ -z "$VALUE_HEX" ]; then
    echo -e "${YELLOW}⚠ Could not parse map data${NC}"
    echo ""
    echo "Raw output:"
    echo "$RAW_OUTPUT"
    exit 0
fi

# Alternative: Use bpftool's JSON output for cleaner parsing
JSON_OUTPUT=$(sudo bpftool map dump id $STATS_MAP_ID -j 2>/dev/null)

if [ ! -z "$JSON_OUTPUT" ]; then
    # Try to parse JSON if available
    echo -e "${GREEN}Total Statistics:${NC}"
    
    # Extract hex values and convert to decimal
    # The structure has 8 x __u64 fields (each 8 bytes)
    
    # For now, show raw hex and let user see it's working
    echo "  Map contents (raw):"
    echo "$RAW_OUTPUT" | grep -A 1 "key:"
    echo ""
    echo -e "${BLUE}Note:${NC} Parsing multi-byte counters from hex dump."
    echo "Values are stored as little-endian 64-bit integers."
else
    echo "Raw map data:"
    echo "$RAW_OUTPUT"
fi

echo ""
echo "─────────────────────────────────────────────"
echo ""

# Better approach: use bpf_map_lookup_elem via a helper program
# For now, show that the map exists and is being updated
echo -e "${BLUE}Alternative View (detailed):${NC}"
sudo bpftool map dump id $STATS_MAP_ID

echo ""
echo -e "${YELLOW}Tip:${NC} For real-time updates, run:"
echo "  watch -n 1 $0"
echo ""

# Show which program is running
PROG_ID=$(sudo bpftool prog show | grep xdp_counter | grep -oP '^\d+' | head -1)
if [ ! -z "$PROG_ID" ]; then
    echo -e "${GREEN}XDP Program Active:${NC}"
    echo "  Program ID: $PROG_ID"
    INTERFACE=$(sudo bpftool net show | grep "xdp:" -A 1 | grep -oP '\w+\(\d+\)' | cut -d'(' -f1)
    if [ ! -z "$INTERFACE" ]; then
        echo "  Interface: $INTERFACE"
    fi
fi
echo ""
