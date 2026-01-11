// SPDX-License-Identifier: GPL-2.0
// XDP Packet Counter - libbpf-based statistics reader
// This demonstrates production-quality BPF map access

#include <stdio.h>
#include <stdlib.h>
#include <errno.h>
#include <string.h>
#include <unistd.h>
#include <bpf/libbpf.h>
#include <bpf/bpf.h>

// Match the kernel structure exactly
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

// ANSI color codes
#define GREEN  "\033[0;32m"
#define YELLOW "\033[1;33m"
#define RED    "\033[0;31m"
#define BLUE   "\033[0;34m"
#define CYAN   "\033[0;36m"
#define BOLD   "\033[1m"
#define NC     "\033[0m"

void print_header(void)
{
    printf(CYAN "╔════════════════════════════════════════════╗\n" NC);
    printf(CYAN "║  XDP Packet Counter (libbpf Native Reader)║\n" NC);
    printf(CYAN "╚════════════════════════════════════════════╝\n" NC);
    printf("\n");
}

void format_bytes(unsigned long long bytes, char *buf, size_t buf_len)
{
    const char *units[] = {"B", "KB", "MB", "GB", "TB"};
    int unit_idx = 0;
    double size = (double)bytes;
    
    while (size >= 1024.0 && unit_idx < 4) {
        size /= 1024.0;
        unit_idx++;
    }
    
    snprintf(buf, buf_len, "%.2f %s", size, units[unit_idx]);
}

void display_stats(const struct pkt_stats *stats)
{
    char bytes_str[64];
    format_bytes(stats->total_bytes, bytes_str, sizeof(bytes_str));
    
    printf(BOLD "Overall Statistics:\n" NC);
    printf("  " GREEN "Total Packets:" NC "  %llu\n", stats->total_packets);
    printf("  " GREEN "Total Bytes:" NC "    %s (%llu bytes)\n", 
           bytes_str, stats->total_bytes);
    printf("\n");
    
    printf(BOLD "By Protocol:\n" NC);
    printf("  " BLUE "ICMP:" NC "  %llu\n", stats->icmp_packets);
    printf("  " BLUE "TCP:" NC "   %llu\n", stats->tcp_packets);
    printf("  " BLUE "UDP:" NC "   %llu\n", stats->udp_packets);
    printf("  " BLUE "Other:" NC " %llu\n", stats->other_packets);
    printf("\n");
    
    printf(BOLD "By IP Version:\n" NC);
    printf("  " BLUE "IPv4:" NC " %llu\n", stats->ipv4_packets);
    printf("  " BLUE "IPv6:" NC " %llu\n", stats->ipv6_packets);
    printf("\n");
    
    // Calculate percentages if there are packets
    if (stats->total_packets > 0) {
        printf(BOLD "Protocol Distribution:\n" NC);
        printf("  ICMP: %5.1f%%\n", 
               (stats->icmp_packets * 100.0) / stats->total_packets);
        printf("  TCP:  %5.1f%%\n", 
               (stats->tcp_packets * 100.0) / stats->total_packets);
        printf("  UDP:  %5.1f%%\n", 
               (stats->udp_packets * 100.0) / stats->total_packets);
        printf("  Other:%5.1f%%\n", 
               (stats->other_packets * 100.0) / stats->total_packets);
        printf("\n");
    }
}

int main(int argc, char **argv)
{
    struct pkt_stats stats = {0};
    int map_fd;
    __u32 key = 0;
    int ret;
    
    print_header();
    
    // Method 1: Open pinned map by path
    printf("Opening BPF map from pinned path...\n");
    map_fd = bpf_obj_get("/sys/fs/bpf/stats_map");
    if (map_fd < 0) {
        fprintf(stderr, RED "✗ Failed to open pinned map: %s\n" NC, 
                strerror(errno));
        fprintf(stderr, "\nIs the XDP program loaded?\n");
        fprintf(stderr, "Run: ./02-load.sh\n");
        return 1;
    }
    
    printf(GREEN "✓ Map opened (fd: %d)\n" NC, map_fd);
    printf("\n");
    
    // Read the statistics from the map
    printf("Reading statistics from BPF map...\n");
    ret = bpf_map_lookup_elem(map_fd, &key, &stats);
    if (ret < 0) {
        fprintf(stderr, RED "✗ Failed to read map: %s\n" NC, 
                strerror(errno));
        close(map_fd);
        return 1;
    }
    
    printf(GREEN "✓ Statistics read successfully\n" NC);
    printf("\n");
    
    // Check if we have any data
    if (stats.total_packets == 0) {
        printf(YELLOW "⚠ No packets counted yet\n" NC);
        printf("\n");
        printf("Generate some traffic:\n");
        printf("  ping -c 5 8.8.8.8\n");
        printf("  curl -s http://example.com > /dev/null\n");
        close(map_fd);
        return 0;
    }
    
    // Display the statistics
    display_stats(&stats);
    
    // Cleanup
    close(map_fd);
    
    printf(YELLOW "Tip:" NC " This is a production-quality libbpf reader\n");
    printf("It directly accesses BPF maps using the libbpf API\n");
    printf("\n");
    printf("For continuous monitoring:\n");
    printf("  watch -n 1 ./stats_reader\n");
    printf("\n");
    
    return 0;
}
