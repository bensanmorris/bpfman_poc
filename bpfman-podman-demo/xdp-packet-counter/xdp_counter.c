// SPDX-License-Identifier: GPL-2.0
// XDP Packet Counter - Count packets by protocol type
// This demo works perfectly on a single machine!

#include <linux/bpf.h>
#include <linux/if_ether.h>
#include <linux/ip.h>
#include <linux/ipv6.h>
#include <linux/in.h>
#include <linux/icmp.h>
#include <linux/tcp.h>
#include <linux/udp.h>
#include <bpf/bpf_helpers.h>
#include <bpf/bpf_endian.h>

// Protocol constants (in case linux/in.h doesn't define them for BPF)
#ifndef IPPROTO_ICMP
#define IPPROTO_ICMP 1
#endif
#ifndef IPPROTO_TCP
#define IPPROTO_TCP 6
#endif
#ifndef IPPROTO_UDP
#define IPPROTO_UDP 17
#endif
#ifndef IPPROTO_ICMPV6
#define IPPROTO_ICMPV6 58
#endif

// Packet statistics structure
struct pkt_stats {
    __u64 total_packets;
    __u64 total_bytes;
    __u64 icmp_packets;
    __u64 tcp_packets;
    __u64 udp_packets;
    __u64 other_packets;
    __u64 ipv4_packets;
    __u64 ipv6_packets;
};

// BPF map to store statistics (shared between kernel and userspace)
struct {
    __uint(type, BPF_MAP_TYPE_ARRAY);
    __uint(max_entries, 1);
    __type(key, __u32);
    __type(value, struct pkt_stats);
} stats_map SEC(".maps");

// Helper to get stats structure
static __always_inline struct pkt_stats* get_stats(void) {
    __u32 key = 0;
    return bpf_map_lookup_elem(&stats_map, &key);
}

SEC("xdp")
int xdp_packet_counter(struct xdp_md *ctx)
{
    void *data_end = (void *)(long)ctx->data_end;
    void *data = (void *)(long)ctx->data;
    
    // Get stats from map
    struct pkt_stats *stats = get_stats();
    if (!stats) {
        return XDP_PASS; // Should never happen, but be safe
    }
    
    // Calculate packet size
    __u64 pkt_size = data_end - data;
    
    // Update total counters
    __sync_fetch_and_add(&stats->total_packets, 1);
    __sync_fetch_and_add(&stats->total_bytes, pkt_size);
    
    // Parse Ethernet header
    struct ethhdr *eth = data;
    if ((void *)(eth + 1) > data_end) {
        return XDP_PASS;
    }
    
    __u16 eth_proto = bpf_ntohs(eth->h_proto);
    
    // Handle IPv4
    if (eth_proto == ETH_P_IP) {
        __sync_fetch_and_add(&stats->ipv4_packets, 1);
        
        struct iphdr *iph = (void *)(eth + 1);
        if ((void *)(iph + 1) > data_end) {
            return XDP_PASS;
        }
        
        // Check protocol
        switch (iph->protocol) {
            case IPPROTO_ICMP:
                __sync_fetch_and_add(&stats->icmp_packets, 1);
                break;
            case IPPROTO_TCP:
                __sync_fetch_and_add(&stats->tcp_packets, 1);
                break;
            case IPPROTO_UDP:
                __sync_fetch_and_add(&stats->udp_packets, 1);
                break;
            default:
                __sync_fetch_and_add(&stats->other_packets, 1);
                break;
        }
    }
    // Handle IPv6
    else if (eth_proto == ETH_P_IPV6) {
        __sync_fetch_and_add(&stats->ipv6_packets, 1);
        
        struct ipv6hdr *ip6h = (void *)(eth + 1);
        if ((void *)(ip6h + 1) > data_end) {
            return XDP_PASS;
        }
        
        // Check next header (protocol)
        switch (ip6h->nexthdr) {
            case IPPROTO_ICMPV6:
                __sync_fetch_and_add(&stats->icmp_packets, 1);
                break;
            case IPPROTO_TCP:
                __sync_fetch_and_add(&stats->tcp_packets, 1);
                break;
            case IPPROTO_UDP:
                __sync_fetch_and_add(&stats->udp_packets, 1);
                break;
            default:
                __sync_fetch_and_add(&stats->other_packets, 1);
                break;
        }
    }
    else {
        __sync_fetch_and_add(&stats->other_packets, 1);
    }
    
    // Always pass packets through (we're just counting, not filtering)
    return XDP_PASS;
}

char _license[] SEC("license") = "GPL";
