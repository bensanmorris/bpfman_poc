# Production BPF Map Access with libbpf

## Overview

This directory contains **three different ways** to read statistics from the XDP packet counter:

1. **Shell script** (`03-show-stats.sh`) - Uses `bpftool` CLI
2. **Python script** (`03-show-stats-python.py`) - Parses `bpftool` output  
3. **Native C program** (`stats_reader.c`) - Uses libbpf API directly ✨ **PRODUCTION APPROACH**

## Why libbpf for Production?

### The libbpf Approach (Recommended for Production)

**File:** `stats_reader.c`

```c
#include <bpf/libbpf.h>
#include <bpf/bpf.h>

// Open pinned BPF map
int map_fd = bpf_obj_get("/sys/fs/bpf/stats_map");

// Read data directly
struct pkt_stats stats;
bpf_map_lookup_elem(map_fd, &key, &stats);

// Use the data
printf("Packets: %llu\n", stats.total_packets);
```

**Advantages:**
- ✅ **Direct API access** - No subprocess calls
- ✅ **Type-safe** - C struct matches kernel struct exactly
- ✅ **Fast** - Native compiled code, minimal overhead
- ✅ **Reliable** - No parsing of text output
- ✅ **Production-ready** - Used by Cilium, Calico, etc.
- ✅ **Self-contained** - Only needs libbpf runtime library

### The bpftool Approach (Good for Debugging)

**Files:** `03-show-stats.sh`, `03-show-stats-python.py`

```bash
# Shell
bpftool map dump id 74

# Python parsing bpftool output
output = subprocess.run(['bpftool', 'map', 'dump', ...])
stats = parse(output)
```

**Advantages:**
- ✅ **Easy to write** - No compilation needed
- ✅ **Good for debugging** - Human-readable output
- ✅ **Flexible** - Quick iteration

**Disadvantages:**
- ❌ Subprocess overhead
- ❌ Text parsing fragile (format changes)
- ❌ No type safety
- ❌ Not suitable for high-frequency polling

## Production Use Cases

### When to use libbpf (C/C++):

1. **High-frequency monitoring** (> 1Hz)
2. **Performance-critical applications**
3. **Container/pod agents** (sidecar patterns)
4. **Long-running daemons**
5. **Integration with C/C++ codebases**

**Examples in the wild:**
- Cilium agent (network policy enforcement)
- Calico Felix (network dataplane)
- Katran (load balancer)
- bpfman daemon itself

### When to use bpftool/Python:

1. **One-off queries**
2. **Debugging/troubleshooting**
3. **Quick scripts**
4. **Low-frequency monitoring** (< 1/min)
5. **Prototyping**

## Building the libbpf Reader

### Prerequisites

```bash
sudo dnf install gcc libbpf-devel
```

### Compile

```bash
./05-compile-libbpf-reader.sh
```

This produces the `stats_reader` binary.

### Run

```bash
sudo ./stats_reader
```

Output:
```
╔════════════════════════════════════════════╗
║  XDP Packet Counter (libbpf Native Reader)║
╚════════════════════════════════════════════╝

Opening BPF map from pinned path...
✓ Map opened (fd: 3)

Reading statistics from BPF map...
✓ Statistics read successfully

Overall Statistics:
  Total Packets:  163
  Total Bytes:    9.99 KB (10,226 bytes)

By Protocol:
  ICMP:  9
  TCP:   8
  UDP:   7
  Other: 139
```

## Code Walkthrough

### 1. Define the Structure (Must Match Kernel!)

```c
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
```

⚠️ **Critical:** This must **exactly match** the kernel structure in `xdp_counter.c`!

### 2. Open the BPF Map

```c
int map_fd = bpf_obj_get("/sys/fs/bpf/stats_map");
```

This opens the **pinned** BPF map. The map was pinned by `bpftool` when we loaded it with:

```bash
bpftool prog load ... pinmaps /sys/fs/bpf/
```

### 3. Read from the Map

```c
__u32 key = 0;  // Array maps use integer keys
struct pkt_stats stats;

int ret = bpf_map_lookup_elem(map_fd, &key, &stats);
```

This is a **direct kernel call** via `bpf()` syscall. No text parsing!

### 4. Use the Data

```c
printf("Total: %llu\n", stats.total_packets);
printf("ICMP: %llu\n", stats.icmp_packets);
```

Type-safe access to structured data.

## Advanced: BPF Skeletons (Next Level)

For even better integration, you can use **BPF skeletons** which auto-generate C code from your BPF program:

```bash
# Generate skeleton header
bpftool gen skeleton xdp_counter.o > xdp_counter.skel.h
```

Then in C:
```c
#include "xdp_counter.skel.h"

struct xdp_counter *skel;
skel = xdp_counter__open_and_load();
skel->maps.stats_map;  // Direct map access!
```

This is what **production eBPF projects** use. We didn't include it here to keep things simple, but it's the recommended approach for complex applications.

## OpenShift Production Deployment

In OpenShift, you would:

1. **Build container with libbpf**
   ```dockerfile
   FROM registry.access.redhat.com/ubi9/ubi
   RUN dnf install -y libbpf
   COPY stats_reader /usr/local/bin/
   CMD ["/usr/local/bin/stats_reader"]
   ```

2. **Run as sidecar or DaemonSet**
   - Main container: XDP program loader (bpfman)
   - Sidecar: Stats reader (stats_reader)
   - Shared: BPF filesystem volume

3. **Export metrics**
   ```c
   // In stats_reader.c
   // Add Prometheus exporter
   // Expose /metrics endpoint
   // Scrape with Prometheus Operator
   ```

## Comparison Table

| Feature | bpftool | Python | libbpf (C) |
|---------|---------|--------|------------|
| Performance | ⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| Type Safety | ❌ | ⭐ | ⭐⭐⭐⭐⭐ |
| Ease of Use | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Production Ready | ⭐ | ⭐⭐ | ⭐⭐⭐⭐⭐ |
| Debugging | ⭐⭐⭐⭐⭐ | ⭐⭐⭐⭐ | ⭐⭐⭐ |
| Dependencies | bpftool | Python + bpftool | libbpf |
| Compilation | None | None | Required |

## Summary

For your OpenShift deployment:

- **Demo/Testing:** Use Python script (`03-show-stats-python.py`)
- **Production Monitoring:** Use libbpf reader (`stats_reader.c`)
- **Debugging:** Use bpftool directly

The libbpf approach demonstrates **production-grade BPF programming** and is what you'll want to show your architects/reviewers as the "real" implementation pattern.

## Further Reading

- [libbpf Documentation](https://libbpf.readthedocs.io/)
- [BPF CO-RE (Compile Once, Run Everywhere)](https://nakryiko.com/posts/bpf-core-reference-guide/)
- [Cilium's use of libbpf](https://docs.cilium.io/en/latest/bpf/)
- [Kernel BPF Documentation](https://www.kernel.org/doc/html/latest/bpf/)
