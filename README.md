# Contents

- **UPDATE:** [eBPF use case list added here](./README_ebpf-use-cases-beyond-networking.md)
- **UPDATE:** [Setting up a RHEL9 instance for eBPF (this page)](./README.md)
- **UPDATE:** [xdp packet counter demo added here (a good single machine demo)](./bpfman-podman-demo/xdp-packet-counter/README.md)
- **UPDATE:** [xdp packet counter demo extended to forward eBPF data to otel](./bpfman-podman-demo/xdp-otel-demo/README.md)
- **UPDATE:** [openshift local setup (pre-requisite for the bpfman-operator demo below)](RHEL9-OpenShift-Setup-README.md)

## In Progress:

- **UPDATE:** [WIP - bpfman as a container demo added here](./bpfman-podman-demo/README.md)

# bpfman Proof of Concept – RHEL 9 (Minimal Setup)

This README documents the **minimal, working setup steps** required to prepare a Red Hat Enterprise Linux 9 system for a **bpfman / eBPF proof of concept**.

The goal at this stage is to verify:
- Kernel eBPF support
- Tooling availability (bpftool, libbpf, clang/llvm)
- A clean foundation for running and managing eBPF programs via **bpfman**

---

## 1. Environment

- **Host OS**: Ubuntu 22.04 (laptop)
- **Guest OS**: RHEL 9 (VM via KVM / virt-manager)
- **Kernel**:
  ```bash
  uname -r
  # 5.14.0-570.12.1.el9_6.x86_64
  ```

---

## 2. Verify Kernel eBPF Support

Check kernel configuration:

```bash
grep CONFIG_BPF /boot/config-$(uname -r)
```

Expected key flags:

```text
CONFIG_BPF=y
CONFIG_BPF_SYSCALL=y
CONFIG_BPF_JIT=y
CONFIG_BPF_JIT_ALWAYS_ON=y
CONFIG_BPF_LSM=y
CONFIG_BPF_EVENTS=y
```

This confirms:
- eBPF is enabled
- JIT is enabled and always on
- LSM hooks are available

---

## 3. Register RHEL System

Development packages require a registered system.

```bash
sudo subscription-manager register
```

Verify registration:

```bash
subscription-manager status
```

---

## 4. Enable CodeReady Builder (CRB)

`*-devel` packages (including `libbpf-devel`) live in CRB.

```bash
sudo subscription-manager repos   --enable=codeready-builder-for-rhel-9-x86_64-rpms
```

Verify:

```bash
dnf repolist | grep codeready
```

---

## 5. Install eBPF Tooling

```bash
sudo dnf install -y   bpftool   clang   llvm   libbpf   libbpf-devel   kernel-devel   kernel-headers
```

---

## 6. Verify Toolchain

### Check libbpf headers
```bash
ls /usr/include/bpf/bpf_helpers.h
```

### Probe kernel eBPF features
```bash
bpftool feature probe | head -20
```

This confirms:
- Kernel helpers available
- Map and program types supported
- JIT functioning correctly

---

## 7. Compile and run a simple eBPF program

### hello.bpf.c

```bash
cat << 'EOF' > hello.bpf.c
#include <linux/bpf.h>
#include <bpf/bpf_helpers.h>

SEC("tracepoint/syscalls/sys_enter_execve")
int hello_execve(void *ctx)
{
    bpf_printk("hello from ebpf: execve called\n");
    return 0;
}

char LICENSE[] SEC("license") = "GPL";
EOF

```

Compile:

```bash
clang -O2 -g -target bpf -c hello.bpf.c -o hello.bpf.o
```

Verify:

```bash
file hello.bpf.o
```

Expected output along the lines of:
```
[benm@localhost ~]$ file hello.bpf.o
hello.bpf.o: ELF 64-bit LSB relocatable, eBPF, version 1 (SYSV), with debug_info, not stripped
```

---

## 8. Load the eBPF Program

```bash
sudo bpftool prog load hello.bpf.o /sys/fs/bpf/hello_execve
```

Verify program is loaded:

```bash
sudo bpftool prog show | grep hello
```

Expected output along the lines of:
```
[benm@localhost ~]$ sudo bpftool prog show | grep hello
48: tracepoint  name hello_execve  tag 7c36a23f8d1b6b84  gpl
```

---

## 9. Validate with bpftrace (Key Sanity Check)

This step definitively proved that eBPF execution works:

Install `bpfrace`:

```bash
sudo dnf install -y bpftrace
```

Open 2 terminals.

In terminal 1:
```bash
sudo bpftrace -e 'tracepoint:syscalls:sys_enter_execve { printf("execve\n"); }'
```

In terminal 2:
```bash
ls
echo
```

Example output in terminal 1:

```
Attaching 1 probe...
execve
execve
execve
```

## 10. Status

At this point the system has:

- ✅ RHEL-supported kernel
- ✅ Full eBPF support enabled
- ✅ libbpf userspace + headers
- ✅ clang/llvm toolchain
- ✅ bpftool available
- ✅ Ready for bpfman-managed eBPF programs

---

# bpfman

## 1. Authenticate to Red Hat Container Registry

Login to the Red Hat registry (required for `bpfman` images):

```bash
sudo podman login registry.redhat.io
```

Uses Red Hat Customer Portal credentials.

---

## 2. Pull Official bpfman Images

Pull a known-good version (0.5.9):

```bash
sudo podman pull registry.redhat.io/bpfman/bpfman:0.5.9
sudo podman pull registry.redhat.io/bpfman/bpfman-agent:0.5.9
```

Verify `bpfman` image:

```bash
sudo podman run --rm -it \
  --privileged \
  --pid=host \
  --network=host \
  registry.redhat.io/bpfman/bpfman:0.5.9 --help
```

Confirmed: container runs and exposes the bpfman RPC service.

---

# Projects

## bpfman Proof of Concept
See the [bpfman demo README](./bpfman-podman-demo/README.md) for complete documentation.

Key features:
- Validates bpfman in containerized environment
- Proves OpenShift deployment requirements
- Includes security approval documentation
