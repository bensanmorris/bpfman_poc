// SPDX-License-Identifier: GPL-2.0
// XDP program to block ICMP ping packets
// Demonstrates basic packet filtering at the network edge

#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

// Ethernet header (14 bytes)
struct ethhdr {
    unsigned char   h_dest[6];      // Destination MAC
    unsigned char   h_source[6];    // Source MAC
    unsigned short  h_proto;        // Protocol (e.g., 0x0800 for IPv4)
} __attribute__((packed));

// IPv4 header (20 bytes minimum)
struct iphdr {
    unsigned char   ihl:4;          // Header length
    unsigned char   version:4;      // Version (4 for IPv4)
    unsigned char   tos;            // Type of service
    unsigned short  tot_len;        // Total length
    unsigned short  id;             // Identification
    unsigned short  frag_off;       // Fragment offset
    unsigned char   ttl;            // Time to live
    unsigned char   protocol;       // Protocol (e.g., 1 for ICMP)
    unsigned short  check;          // Header checksum
    unsigned int    saddr;          // Source IP address
    unsigned int    daddr;          // Destination IP address
} __attribute__((packed));

// ICMP header (8 bytes)
struct icmphdr {
    unsigned char   type;           // ICMP type (8 = Echo Request/ping)
    unsigned char   code;           // ICMP code
    unsigned short  checksum;       // Checksum
    unsigned short  id;             // Identifier
    unsigned short  sequence;       // Sequence number
} __attribute__((packed));

// Protocol constants
#define ETH_P_IP    0x0800          // IPv4 protocol
#define IPPROTO_ICMP 1              // ICMP protocol number
#define ICMP_ECHO   8               // ICMP Echo Request (ping)

// License required for eBPF programs
char LICENSE[] SEC("license") = "GPL";

// XDP program section - this is what bpfman will load
SEC("xdp")
int xdp_block_ping(struct xdp_md *ctx)
{
    // Get packet start and end pointers
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;
    
    // Parse Ethernet header
    struct ethhdr *eth = data;
    
    // Bounds check: ensure we can safely read Ethernet header
    if ((void *)(eth + 1) > data_end)
        return XDP_PASS;  // Packet too small, pass it through
    
    // Only process IPv4 packets (0x0800 = ETH_P_IP)
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS;  // Not IPv4, pass it through
    
    // Parse IP header
    struct iphdr *iph = (void *)(eth + 1);
    
    // Bounds check: ensure we can safely read IP header
    if ((void *)(iph + 1) > data_end)
        return XDP_PASS;
    
    // Check if this is ICMP (protocol 1)
    if (iph->protocol != IPPROTO_ICMP)
        return XDP_PASS;  // Not ICMP, pass it through
    
    // Parse ICMP header (account for variable IP header length)
    struct icmphdr *icmph = (void *)iph + (iph->ihl * 4);
    
    // Bounds check: ensure we can safely read ICMP header
    if ((void *)(icmph + 1) > data_end)
        return XDP_PASS;
    
    // Block ICMP Echo Request (ping) packets (type 8)
    if (icmph->type == ICMP_ECHO) {
        // Log to kernel trace pipe for debugging
        bpf_printk("XDP: Blocking ICMP ping from %x\n", bpf_ntohl(iph->saddr));
        return XDP_DROP;  // DROP the packet at the network edge!
    }
    
    // Allow all other ICMP packets (echo reply, etc.)
    return XDP_PASS;
}
