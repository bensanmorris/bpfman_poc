# bpfman Proof of Concept Demo

Quick demonstration of bpfman running in a containerized environment with all requirements for OpenShift deployment.

## Quick Start

```bash
# 1. Switch to Podman (if using Docker)
./01-switch-to-podman.sh

# 2. Run the demo
./02-run-demo.sh
```

**Requirements:**
- RHEL 9 (or compatible)
- Podman
- Red Hat registry credentials (free account at https://registry.redhat.com)
- sudo access

## What This Proves

This demo validates **all technical requirements** for OpenShift deployment:

| Requirement | Validation |
|------------|------------|
| ✅ Privileged container execution | Container runs with `privileged: true` |
| ✅ SELinux compatibility | Uses `spc_t` context successfully |
| ✅ BPF filesystem access | `/sys/fs/bpf` mounted and accessible |
| ✅ Linux capabilities | BPF, NET_ADMIN, SYS_ADMIN granted |
| ✅ Host network/PID access | `hostNetwork` and `hostPID` work |
| ✅ Red Hat enterprise images | Uses `registry.redhat.io/bpfman/bpfman:0.5.9` |

**Success Indicator:**
```
[INFO  bpfman_rpc::serve] Listening on /run/bpfman-sock/bpfman.sock
```

## Architecture Overview

### Production OpenShift Deployment

```
┌─────────────────────────────────────────────┐
│           OpenShift Cluster                 │
│                                             │
│  ┌───────────────────────────────────────┐ │
│  │  bpfman DaemonSet (per node)          │ │
│  │  - Image: bpfman:0.5.9                │ │
│  │  - Runs: bpfman-rpc server            │ │
│  │  - Privileges: Custom SCC              │ │
│  │  - Mounts: /sys/fs/bpf (host)         │ │
│  └───────────────────────────────────────┘ │
│                    │                        │
│                    │ gRPC                   │
│                    ↓                        │
│  ┌───────────────────────────────────────┐ │
│  │  bpfman-operator (Deployment)         │ │
│  │  - Manages: eBPF program lifecycle    │ │
│  │  - Uses: Kubernetes CRDs              │ │
│  │  - Connects: to bpfman-rpc via socket │ │
│  └───────────────────────────────────────┘ │
│                                             │
└─────────────────────────────────────────────┘
```

### Component Breakdown

**bpfman (DaemonSet)**
- **What it does:** Manages eBPF programs on each node
- **Deployment:** One pod per node (DaemonSet)
- **Image:** `registry.redhat.io/bpfman/bpfman:0.5.9`
- **Process:** `bpfman-rpc` (gRPC server)
- **Requires:** Privileged access, custom SCC, host filesystem mounts

**bpfman-operator (Deployment)**
- **What it does:** Kubernetes operator for declarative eBPF management
- **Deployment:** Single or replicated Deployment
- **Image:** `registry.redhat.io/bpfman/bpfman-rhel9-operator`
- **Interface:** Kubernetes Custom Resources (CRDs)
- **Communication:** gRPC to bpfman-rpc on each node

**eBPF Programs (Custom Resources)**
- **What they are:** Kubernetes CRDs defining eBPF programs
- **Examples:** XdpProgram, TcProgram, TracepointProgram
- **Lifecycle:** Managed by bpfman-operator
- **Loading:** Operator instructs bpfman-rpc to load/unload

### This Demo

**What we're testing:**
- ✅ The **bpfman DaemonSet** component
- ✅ All required privileges and mounts
- ✅ SELinux compatibility
- ✅ Container can start and serve gRPC

**What we're NOT testing:**
- ❌ bpfman-operator (requires full OpenShift)
- ❌ Loading actual eBPF programs (requires operator or CLI)
- ❌ Multi-node cluster behavior

**Why this is sufficient:**
The DaemonSet is the critical component requiring privileged access and custom SCC. Once this works, the operator is standard Kubernetes deployment.

## OpenShift Deployment Pattern

### 1. Custom SCC (Security Context Constraint)
```yaml
apiVersion: security.openshift.io/v1
kind: SecurityContextConstraints
metadata:
  name: bpfman-scc
allowPrivilegedContainer: true
allowHostNetwork: true
allowHostPID: true
allowHostDirVolumePlugin: true
allowedCapabilities:
  - SYS_ADMIN
  - NET_ADMIN
  - BPF
seLinuxContext:
  type: spc_t  # Super Privileged Container
```

### 2. DaemonSet
```yaml
apiVersion: apps/v1
kind: DaemonSet
metadata:
  name: bpfman
  namespace: bpfman
spec:
  template:
    spec:
      serviceAccountName: bpfman
      hostNetwork: true
      hostPID: true
      containers:
      - name: bpfman
        image: registry.redhat.io/bpfman/bpfman:0.5.9
        securityContext:
          privileged: true
          seLinuxOptions:
            type: spc_t
```

### 3. Operator (Standard Deployment)
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: bpfman-operator
  namespace: bpfman
spec:
  template:
    spec:
      containers:
      - name: operator
        image: registry.redhat.io/bpfman/bpfman-rhel9-operator
        # No special privileges needed
```

## Files

- `01-switch-to-podman.sh` - Remove Docker, install Podman
- `02-run-demo.sh` - Run complete demo
- `bpfman-openshift.yaml` - Complete OpenShift manifests (DaemonSet + SCC)
- `cleanup.sh` - Remove demo pod

## Next Steps for Corporate OpenShift

1. **Submit SCC Request**
   - Use `bpfman-openshift.yaml` as reference
   - Request from OpenShift cluster admins

2. **Deploy to Dev Cluster**
   ```bash
   oc login <dev-cluster>
   oc apply -f bpfman-openshift.yaml
   oc get daemonset -n bpfman
   ```

3. **Install Operator**
   ```bash
   oc apply -f bpfman-operator.yaml
   oc get deployment -n bpfman
   ```

4. **Load eBPF Programs**
   ```yaml
   apiVersion: bpfman.io/v1alpha1
   kind: XdpProgram
   metadata:
     name: xdp-pass
   spec:
     bpffunctionname: pass
     bytecode:
       image:
         url: quay.io/bpfman-bytecode/xdp_pass:latest
     interfaceselector:
       primarynodeinterface: true
   ```

## Troubleshooting

**Socket not found:**
```bash
sudo podman exec bpfman-demo-pod-bpfman ls -l /run/bpfman-sock/
```

**SELinux blocking:**
```bash
sudo ausearch -m avc -ts recent
# Should see spc_t context being used
```

**View logs:**
```bash
sudo podman logs bpfman-demo-pod-bpfman
```

## Success Criteria

Demo is successful when you see:
- ✅ Pod status: Running
- ✅ Logs show: "Listening on /run/bpfman-sock/bpfman.sock"
- ✅ Socket exists at `/run/bpfman-sock/bpfman.sock`
- ✅ BPF filesystem accessible at `/sys/fs/bpf`

## Resources

- bpfman Documentation: https://github.com/bpfman/bpfman
- OpenShift SCC Guide: https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html
- Red Hat Container Catalog: https://catalog.redhat.com/software/containers/search?q=bpfman

