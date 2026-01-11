#!/bin/bash
# Diagnose BPF map issues

GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}╔════════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║         BPF Map Diagnostics                ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════════╝${NC}"
echo ""

echo "1. Looking for stats_map..."
sudo bpftool map show | grep -A 2 stats_map
echo ""

echo "2. Finding map ID..."
STATS_MAP_ID=$(sudo bpftool map show | grep stats_map | grep -oP '^\d+' | head -1)
if [ -z "$STATS_MAP_ID" ]; then
    echo -e "${RED}✗ stats_map not found!${NC}"
    exit 1
fi
echo -e "${GREEN}✓ Found map ID: $STATS_MAP_ID${NC}"
echo ""

echo "3. Dumping raw map data..."
sudo bpftool map dump id $STATS_MAP_ID
echo ""

echo "4. Dumping map in JSON format..."
sudo bpftool map dump id $STATS_MAP_ID -j 2>/dev/null || echo "(JSON not available)"
echo ""

echo "5. Map details..."
sudo bpftool map show id $STATS_MAP_ID
echo ""

echo "6. Checking XDP program..."
PROG_ID=$(sudo bpftool prog show | grep xdp_packet_counter | grep -oP '^\d+' | head -1)
if [ ! -z "$PROG_ID" ]; then
    echo -e "${GREEN}✓ XDP program ID: $PROG_ID${NC}"
    echo ""
    echo "Program details:"
    sudo bpftool prog show id $PROG_ID
    echo ""
    echo "XDP attachment:"
    sudo bpftool net show | grep -A 2 xdp
else
    echo -e "${RED}✗ XDP program not found${NC}"
fi
echo ""

echo "7. Trying to update map (initialize counters)..."
# Create a zero-filled value (64 bytes for 8 x __u64)
ZERO_VALUE="00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000"
echo "   Updating key 0 with zeros..."
echo "$ZERO_VALUE" | xxd -r -p | sudo bpftool map update id $STATS_MAP_ID key 0 0 0 0 value hex - 2>&1 || echo "   (Update may have failed)"
echo ""

echo "8. Dumping map again after initialization..."
sudo bpftool map dump id $STATS_MAP_ID
echo ""
