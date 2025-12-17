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

## 7. Status

At this point the system has:

- ✅ RHEL-supported kernel
- ✅ Full eBPF support enabled
- ✅ libbpf userspace + headers
- ✅ clang/llvm toolchain
- ✅ bpftool available
- ✅ Ready for bpfman-managed eBPF programs

---

## Next Steps (Not Yet Performed)

- Deploy and configure **bpfman**
- Load eBPF programs declaratively via CRDs
- Demonstrate enable/disable per node
- Optional: LSM, tracing, or networking programs

