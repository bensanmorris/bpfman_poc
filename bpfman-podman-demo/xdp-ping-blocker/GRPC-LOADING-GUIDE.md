# Loading XDP Programs via bpfman gRPC API

## Overview

This directory now includes **three methods** to load XDP programs:

1. **02-load-xdp-program.sh** - Host-based loading (direct bpftool)
2. **02b-load-via-grpc.sh** - gRPC API loading (grpcurl)
3. **02c-load-via-grpc-python.py** - Python gRPC client

Methods 2 and 3 demonstrate **how bpfman-operator actually works** in OpenShift!

## Why gRPC Matters

In production OpenShift, the **bpfman-operator** doesn't use bpftool directly. Instead:

```
Developer creates CRD
       ↓
bpfman-operator detects it
       ↓
Operator makes gRPC call to bpfman-rpc
       ↓
bpfman-rpc loads program into kernel
       ↓
XDP active!
```

Our gRPC scripts demonstrate **step 3** - the actual API communication method.

## Method Comparison

| Method | Tool | Use Case | Corporate Value |
|--------|------|----------|-----------------|
| 02-load-xdp-program.sh | bpftool | Manual testing | Proves XDP works |
| **02b-load-via-grpc.sh** | grpcurl | **API demo** | **Shows bpfman API** |
| 02c-load-via-grpc-python.py | Python | Programmatic | How to automate |

## Method 1: Host-Based (bpftool)

**What it does:**
```bash
sudo bpftool prog load xdp_block_ping.o /sys/fs/bpf/xdp_block_ping type xdp
sudo bpftool net attach xdp id $PROG_ID dev eth0
```

**Pros:**
- ✅ Simple and direct
- ✅ No additional tools needed
- ✅ Proves XDP capability

**Cons:**
- ❌ Not how OpenShift works
- ❌ Doesn't demonstrate bpfman API

## Method 2: gRPC with grpcurl (Recommended for Demo)

**What it does:**
```bash
./02b-load-via-grpc.sh
```

This script:
1. Installs `grpcurl` if needed (gRPC CLI tool)
2. Base64-encodes the bytecode
3. Makes gRPC API call to bpfman-rpc:
   ```bash
   grpcurl -unix /run/bpfman-sock/bpfman.sock \
     bpfman.v1.Bpfman/Load \
     -d '{"bytecode": "...", "name": "xdp_block_ping"}'
   ```
4. Verifies the program loaded

**Pros:**
- ✅ **Demonstrates actual bpfman API**
- ✅ Shows gRPC communication
- ✅ Same method operator uses
- ✅ Easy to understand

**Cons:**
- Requires grpcurl installation (auto-handled)

### Installing grpcurl

The script auto-installs, but manual options:

```bash
# Via Go
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest

# Or download binary
curl -L https://github.com/fullstorydev/grpcurl/releases/download/v1.8.9/grpcurl_1.8.9_linux_x86_64.tar.gz | tar xz
sudo mv grpcurl /usr/local/bin/
```

## Method 3: Python gRPC Client

**What it does:**
```bash
./02c-load-via-grpc-python.py
```

This demonstrates programmatic access - how you'd integrate bpfman into custom tooling.

**Pros:**
- ✅ Shows programmatic API usage
- ✅ Easy to extend/customize
- ✅ Type-safe with proper proto files

**Cons:**
- Requires Python grpcio library
- Needs .proto files for full implementation

## bpfman gRPC API Details

### Service: `bpfman.v1.Bpfman`

Key methods:

| Method | Purpose |
|--------|---------|
| **Load** | Load and attach eBPF program |
| **Unload** | Remove eBPF program |
| **List** | List all loaded programs |
| **Get** | Get info about specific program |
| **PullBytecode** | Pull bytecode from registry |

### Load Request Format

```json
{
  "bytecode": "<base64-encoded .o file>",
  "name": "xdp_block_ping",
  "program_type": 6,
  "attach_info": {
    "xdp": {
      "iface": "eth0",
      "priority": 50,
      "proceed_on": []
    }
  }
}
```

**Program Types:**
- `6` = XDP
- `1` = Tracepoint
- `2` = TC (Traffic Control)
- `5` = Kprobe

### Socket Location

```bash
unix:///run/bpfman-sock/bpfman.sock
```

This socket is:
- Created by bpfman-rpc on startup
- Mounted as shared volume in pod
- Accessible from bpfman-agent container
- Used by operator for all API calls

## Usage Examples

### Quick Test (grpcurl)

```bash
# Compile
./01-compile-xdp.sh

# Load via gRPC API
./02b-load-via-grpc.sh

# Unload
./03-unload-xdp-program.sh
```

### List Programs via gRPC

```bash
sudo podman exec bpfman-demo-pod-bpfman \
  grpcurl -plaintext -unix /run/bpfman-sock/bpfman.sock \
  bpfman.v1.Bpfman/List
```

### Get Program Info

```bash
sudo podman exec bpfman-demo-pod-bpfman \
  grpcurl -plaintext -unix /run/bpfman-sock/bpfman.sock \
  -d '{"id": "12345"}' \
  bpfman.v1.Bpfman/Get
```

### Unload via gRPC

```bash
sudo podman exec bpfman-demo-pod-bpfman \
  grpcurl -plaintext -unix /run/bpfman-sock/bpfman.sock \
  -d '{"id": "12345"}' \
  bpfman.v1.Bpfman/Unload
```

## OpenShift Production Equivalent

### What Developer Does (OpenShift):

```yaml
apiVersion: bpfman.io/v1alpha1
kind: XdpProgram
metadata:
  name: xdp-ping-blocker
spec:
  bpffunctionname: xdp_block_ping
  interfaceselector:
    primarynodeinterface: true
  bytecode:
    image:
      url: quay.io/myorg/xdp-ping-blocker:latest
```

### What Happens Behind the Scenes:

```
1. kubectl apply -f xdp-program.yaml
2. bpfman-operator watches for XdpProgram CRD
3. Operator reads bytecode from container image
4. Operator makes gRPC call to bpfman-rpc:
   
   grpc.Load({
     bytecode: <bytes from image>,
     name: "xdp_block_ping",
     program_type: XDP,
     attach_info: {xdp: {iface: "eth0"}}
   })
   
5. bpfman-rpc loads into kernel
6. Operator updates CRD status
```

**Our POC demonstrates step 4** - the actual gRPC API call!

## Troubleshooting

### "grpcurl not found"

The script auto-installs, but if it fails:

```bash
# Manual install
go install github.com/fullstorydev/grpcurl/cmd/grpcurl@latest
export PATH=$PATH:$HOME/go/bin
```

### "connection refused"

Check bpfman socket:
```bash
sudo podman exec bpfman-demo-pod-bpfman ls -l /run/bpfman-sock/
```

Should see: `bpfman.sock`

### "unknown service"

List available services:
```bash
sudo podman exec bpfman-demo-pod-bpfman \
  grpcurl -plaintext -unix /run/bpfman-sock/bpfman.sock list
```

### "invalid bytecode"

Verify bytecode is valid:
```bash
file xdp_block_ping.o
# Should show: ELF 64-bit LSB relocatable, eBPF
```

## Advanced: Custom gRPC Client

To build a full gRPC client:

1. **Clone bpfman repo for proto files:**
   ```bash
   git clone https://github.com/bpfman/bpfman
   cd bpfman/bpfman/proto
   ```

2. **Generate Python stubs:**
   ```bash
   python -m grpc_tools.protoc \
     -I. \
     --python_out=. \
     --grpc_python_out=. \
     bpfman.proto
   ```

3. **Import and use:**
   ```python
   import grpc
   import bpfman_pb2
   import bpfman_pb2_grpc
   
   channel = grpc.insecure_channel('unix:///run/bpfman-sock/bpfman.sock')
   stub = bpfman_pb2_grpc.BpfmanStub(channel)
   
   request = bpfman_pb2.LoadRequest(
       bytecode=bytecode,
       name="xdp_block_ping",
       program_type=bpfman_pb2.XDP
   )
   
   response = stub.Load(request)
   ```

## Corporate POC Value

By demonstrating gRPC API loading, you prove:

✅ **Architecture Understanding**  
   Shows you understand how bpfman-operator works

✅ **API Integration Capability**  
   Can integrate bpfman into custom tooling

✅ **Production-Ready Approach**  
   Same method used in OpenShift deployment

✅ **Automation Path**  
   Clear path to automating eBPF management

## Recommended Demo Flow

For stakeholders, use this sequence:

1. **Show direct load** (02-load-xdp-program.sh)  
   "Here's the basic capability - XDP filters work"

2. **Show gRPC load** (02b-load-via-grpc.sh)  
   "Here's how it ACTUALLY works in OpenShift - via API"

3. **Explain production**  
   "In OpenShift, the operator does this automatically"

This progression shows:
- Basic capability ✓
- API-driven management ✓
- Production deployment path ✓

## Summary

| Script | Best For | Corporate Appeal |
|--------|----------|------------------|
| 02-load-xdp-program.sh | Quick test | Proves it works |
| **02b-load-via-grpc.sh** | **Demo** | **Shows architecture** |
| 02c-load-via-grpc-python.py | Automation | Integration example |

**Recommendation:** Use **02b-load-via-grpc.sh** for POC presentations to demonstrate the actual API-driven architecture that OpenShift uses.
