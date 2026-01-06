# XDP Ping Blocker Demo

**Corporate POC: Dynamic eBPF Security Policy Enforcement**

This demo demonstrates the complete lifecycle of an eBPF XDP (eXpress Data Path) program:
1. Compile eBPF program from C source
2. Load into kernel via bpfman
3. Attach to network interface
4. Verify packet filtering
5. Detach and unload

## What This Demonstrates

### Technical Capabilities
- ✅ **XDP packet filtering** at the network edge (fastest possible)
- ✅ **Dynamic policy enforcement** (load/unload without reboot)
- ✅ **Zero-overhead filtering** (packets dropped before kernel stack)
- ✅ **Safe kernel programming** (eBPF verified at load time)
- ✅ **Observable behavior** (kernel trace logs)

### Corporate Value
- 🎯 **Security**: Block malicious traffic at the earliest point
- 🎯 **Performance**: XDP is faster than iptables/nftables
- 🎯 **Agility**: Deploy security policies in seconds, not hours
- 🎯 **Safety**: No kernel modules needed (eBPF is verified)
- 🎯 **Visibility**: Built-in observability via trace logs

## Architecture

```
┌─────────────────────────────────────────┐
│         Network Interface (NIC)         │
└──────────────┬──────────────────────────┘
               │ Packet arrives
               ↓
    ┌──────────────────────┐
    │  XDP Hook (Kernel)   │ ← Our eBPF program runs HERE
    │  xdp_block_ping()    │    (Before kernel network stack)
    └──────────┬───────────┘
               │
         ┌─────┴─────┐
         │           │
    XDP_DROP    XDP_PASS
    (blocked)   (allowed)
         │           │
         ↓           ↓
      Dropped   Kernel TCP/IP Stack
```

## Prerequisites

1. **bpfman running** - Run the parent demo first:
   ```bash
   cd ..
   ./run-bpfman-demo.sh
   ```

2. **Build tools** (auto-installed by script if missing):
   ```bash
   sudo dnf install -y clang llvm kernel-headers kernel-devel bpftool
   ```

## Quick Start

### Step 1: Compile the XDP Program
```bash
./01-compile-xdp.sh
```

**What happens:**
- Compiles `xdp_block_ping.c` to eBPF bytecode
- Creates `xdp_block_ping.o` (the compiled program)
- Verifies the bytecode is valid

**Expected output:**
```
✓ Compilation successful!
✓ Output file created: xdp_block_ping.o
```

### Step 2: Load and Attach the Program
```bash
./02-load-xdp-program.sh
```

**What happens:**
- Copies program into bpfman container
- Loads eBPF bytecode into kernel
- Attaches to your primary network interface
- Tests that ping is now blocked

**Expected output:**
```
✓ XDP program loaded into kernel
✓ Attached to interface: eth0
✓ Ping BLOCKED! XDP filter is working! 🎉
```

### Step 3: Test the Filter

Try to ping Google:
```bash
ping 8.8.8.8
```

**Expected:** Timeout (no response) because XDP is dropping ICMP packets!

Check kernel logs to see the filter in action:
```bash
sudo podman exec bpfman-demo-pod-bpfman \
    cat /sys/kernel/debug/tracing/trace_pipe
```

Look for messages like:
```
XDP: Blocking ICMP ping from 192.168.1.100
```

### Step 4: Unload the Program
```bash
./03-unload-xdp-program.sh
```

**What happens:**
- Detaches XDP program from interface
- Removes program from kernel
- Verifies ping works again

**Expected output:**
```
✓ XDP program successfully removed
✓ Ping works! XDP filter removed successfully! 🎉
```

## The XDP Program Explained

### Code Walkthrough (`xdp_block_ping.c`)

```c
SEC("xdp")
int xdp_block_ping(struct xdp_md *ctx)
{
    // Parse packet headers: Ethernet → IP → ICMP
    
    // 1. Check if IPv4 packet
    if (eth->h_proto != bpf_htons(ETH_P_IP))
        return XDP_PASS;  // Not IPv4, allow it
    
    // 2. Check if ICMP protocol
    if (iph->protocol != IPPROTO_ICMP)
        return XDP_PASS;  // Not ICMP, allow it
    
    // 3. Check if ICMP Echo Request (ping)
    if (icmph->type == ICMP_ECHO) {
        bpf_printk("Blocking ping!");
        return XDP_DROP;  // DROP IT!
    }
    
    return XDP_PASS;  // Allow everything else
}
```

**Key concepts:**
- **XDP_DROP**: Drop packet immediately (fastest possible)
- **XDP_PASS**: Allow packet to continue to kernel
- **Bounds checking**: Required for eBPF verifier safety
- **bpf_printk**: Logs to kernel trace for debugging

## Corporate Deployment Scenarios

### Scenario 1: DDoS Mitigation
**Use case:** Block SYN flood attacks
```c
// Modify program to drop excessive SYN packets from same source
if (tcp->syn && !tcp->ack) {
    // Rate limit or block
    return XDP_DROP;
}
```

### Scenario 2: Network Segmentation
**Use case:** Block traffic between specific pods
```c
// Drop packets from specific source IP ranges
if (is_blocked_subnet(iph->saddr)) {
    return XDP_DROP;
}
```

### Scenario 3: Protocol Filtering
**Use case:** Only allow HTTPS on production interfaces
```c
// Drop all non-443 TCP traffic
if (tcp->dest != htons(443)) {
    return XDP_DROP;
}
```

## Performance Benefits

### XDP vs Traditional Filtering

| Method | Packets/sec | CPU Usage | Latency |
|--------|------------|-----------|---------|
| iptables | 1M | High | ~100µs |
| nftables | 2M | Medium | ~50µs |
| **XDP** | **10M+** | **Low** | **~10µs** |

**Why XDP is faster:**
- Runs before kernel allocates socket buffers
- No context switches to userspace
- Direct access to packet memory
- Can drop packets with minimal CPU cycles

## Troubleshooting

### "XDP not attached"
**Problem:** Driver doesn't support native XDP

**Solution:** Check driver support:
```bash
ethtool -i eth0 | grep driver
```

Some drivers only support "generic" XDP (slower):
```bash
ip link set dev eth0 xdpgeneric obj xdp_block_ping.o sec xdp
```

### "Ping still works after loading"
**Possible causes:**
1. XDP attached to wrong interface
2. Need to test from external host (not localhost)
3. Driver doesn't support XDP

**Debug:**
```bash
# Check which interface has XDP
sudo podman exec bpfman-demo-pod-bpfman bpftool net show

# Try from another machine
# ssh other-host
# ping <this-host-ip>
```

### "Compilation failed"
**Problem:** Missing kernel headers

**Solution:**
```bash
# Install kernel headers
sudo dnf install -y kernel-devel-$(uname -r)

# Verify
ls /lib/modules/$(uname -r)/build
```

## Advanced: Viewing eBPF Internals

### Inspect loaded program
```bash
sudo podman exec bpfman-demo-pod-bpfman \
    bpftool prog show pinned /sys/fs/bpf/xdp_block_ping
```

### Dump eBPF bytecode
```bash
sudo podman exec bpfman-demo-pod-bpfman \
    bpftool prog dump xlated pinned /sys/fs/bpf/xdp_block_ping
```

### View JIT-compiled assembly
```bash
sudo podman exec bpfman-demo-pod-bpfman \
    bpftool prog dump jited pinned /sys/fs/bpf/xdp_block_ping
```

## Next Steps

### Extend the Demo

1. **Add statistics map** - Count blocked packets
2. **Rate limiting** - Allow N pings per second
3. **Allowlist** - Block all except specific IPs
4. **Load balancing** - Distribute packets across CPUs

### Production Considerations

1. **Multiple programs** - Chain XDP programs together
2. **Program updates** - Hot-swap without downtime
3. **Monitoring** - Integrate with Prometheus
4. **Automation** - Deploy via Kubernetes CRDs

## Files in This Demo

```
xdp-ping-blocker/
├── README.md                      # This file
├── xdp_block_ping.c              # XDP program source code
├── 01-compile-xdp.sh             # Compile eBPF program
├── 02-load-xdp-program.sh        # Load and attach
└── 03-unload-xdp-program.sh      # Unload and cleanup
```

## Corporate POC Checklist

Use this demo to prove to stakeholders:

- [x] eBPF programs can be loaded dynamically
- [x] Kernel-level packet filtering works
- [x] No service disruption during load/unload
- [x] Performance is superior to traditional methods
- [x] Safety: eBPF verifier prevents kernel crashes
- [x] Observability: Kernel trace logs available
- [x] Compatible with RHEL 9 and OpenShift

## OpenShift Deployment Path

This demo uses **direct bpftool** because Red Hat images don't include `bpfmanctl`.

In production OpenShift, you would:
1. Deploy **bpfman-operator** (Kubernetes operator)
2. Create **XdpProgram CRD** resources
3. Operator handles load/unload automatically
4. Declarative management via YAML

**Example OpenShift manifest:**
```yaml
apiVersion: bpfman.io/v1alpha1
kind: XdpProgram
metadata:
  name: xdp-ping-blocker
spec:
  bpffunctionname: xdp_block_ping
  nodeselector:
    kubernetes.io/os: linux
  interfaceselector:
    primarynodeinterface: true
  bytecode:
    path: /xdp_block_ping.o
```

## References

- [XDP Documentation](https://www.kernel.org/doc/html/latest/networking/xdp.html)
- [bpfman Project](https://github.com/bpfman/bpfman)
- [eBPF Tutorial](https://ebpf.io/what-is-ebpf)
- [BPF Performance](https://www.brendangregg.com/blog/2019-01-01/learn-ebpf-tracing.html)

## Support

**Questions?** This is a POC demo. For production deployment:
1. Review OpenShift bpfman-operator documentation
2. Engage Red Hat support for SCC requirements
3. Test in dev cluster before production

---

**Demo Status:** ✅ Production-Ready Concept  
**Last Updated:** 2026-01-06  
**RHEL Version:** 9.x  
**Kernel Version:** 5.14+
