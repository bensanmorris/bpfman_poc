// SPDX-License-Identifier: GPL-2.0
// XDP program to block ICMP ping packets
// Demonstrates basic packet filtering at the network edge

#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/icmp.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

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
    
    // Parse ICMP header
    struct icmphdr *icmph = (void *)iph + (iph->ihl * 4);
    
    // Bounds check: ensure we can safely read ICMP header
    if ((void *)(icmph + 1) > data_end)
        return XDP_PASS;
    
    // Block ICMP Echo Request (ping) packets (type 8)
    if (icmph->type == ICMP_ECHO) {
        // Log to kernel trace pipe for debugging
        bpf_printk("XDP: Blocking ICMP ping from %pI4\n", &iph->saddr);
        return XDP_DROP;  // DROP the packet at the network edge!
    }
    
    // Allow all other ICMP packets (echo reply, etc.)
    return XDP_PASS;
}
