# Corporate OpenShift Deployment Guide

## Executive Summary

This document outlines the requirements and justification for deploying bpfman (eBPF manager) on our corporate OpenShift environment.

**Purpose**: Enable advanced observability, security monitoring, and network analysis using eBPF technology.

**Security Impact**: Requires privileged access and custom Security Context Constraints (SCC).

## What is bpfman?

bpfman is a system daemon that manages eBPF programs, enabling:
- Network packet inspection and filtering
- System call monitoring
- Performance profiling
- Security event detection
- Custom observability without application changes

## Technical Requirements

### 1. Security Context Constraints (SCC)

**Custom SCC Required**: `bpfman-scc`

**Justification for Privileges**:

| Permission | Why Required | Security Mitigation |
|------------|--------------|---------------------|
| `allowPrivilegedContainer: true` | Access to kernel BPF subsystem | DaemonSet pattern limits scope |
| `allowHostNetwork: true` | Monitor network traffic | Read-only access to packets |
| `allowHostPID: true` | Attach to system processes | No process manipulation |
| `allowHostDirVolumePlugin: true` | Access /sys/fs/bpf filesystem | Specific path only |
| `CAP_BPF` | Load eBPF programs | Modern, restricted capability |
| `CAP_NET_ADMIN` | Attach to network interfaces | Limited to observation |
| `CAP_SYS_ADMIN` | Legacy eBPF operations (pre-5.8 kernels) | Required for RHEL compatibility |

**SELinux Context**: `spc_t` (Super Privileged Container)

### 2. Resource Requirements

**Per Node**:
- Memory: 128Mi request, 512Mi limit
- CPU: 100m request, 500m limit
- Disk: Minimal (program storage in /sys/fs/bpf)

**Cluster-wide**:
- DaemonSet: One pod per node
- Total resources scale linearly with node count

### 3. Network Requirements

- **Inbound**: None (DaemonSet doesn't accept external traffic)
- **Outbound**: Image registry access (registry.redhat.io)
- **Internal**: gRPC on Unix socket (no network exposure)

### 4. Storage Requirements

**Host Path Mounts** (Read-Only where possible):
- `/sys/fs/bpf` - BPF filesystem (read/write)
- `/sys/kernel/debug` - Kernel debug info (read-only)
- `/lib/modules` - Kernel modules (read-only)

## Deployment Architecture
```
┌─────────────────────────────────────────┐
│         OpenShift Cluster               │
│                                         │
│  ┌─────────────────────────────────┐   │
│  │  bpfman Namespace               │   │
│  │                                 │   │
│  │  ┌──────────┐  ┌──────────┐    │   │
│  │  │ bpfman   │  │ bpfman   │    │   │
│  │  │ (Node 1) │  │ (Node 2) │... │   │
│  │  └──────────┘  └──────────┘    │   │
│  │       │              │          │   │
│  │       ↓              ↓          │   │
│  │  ┌────────────────────────┐    │   │
│  │  │  bpfman-operator       │    │   │
│  │  │  (Manages eBPF CRDs)   │    │   │
│  │  └────────────────────────┘    │   │
│  └─────────────────────────────────┘   │
│                                         │
└─────────────────────────────────────────┘
```

**Components**:
- **bpfman DaemonSet**: Runs on every node, manages eBPF programs
- **bpfman-operator**: Kubernetes operator, manages CRDs
- **eBPF Programs**: Custom Resources defining programs to load

## Security Review Checklist

### Required Approvals

- [ ] **Security Team**: Custom SCC approval
- [ ] **Platform Team**: DaemonSet deployment approval
- [ ] **Network Team**: Host networking justification
- [ ] **Compliance**: Audit logging requirements

### Security Mitigations

1. **Namespace Isolation**: Dedicated `bpfman` namespace
2. **RBAC**: Minimal ClusterRole permissions
3. **Resource Limits**: CPU and memory constraints
4. **Audit Logging**: All eBPF program loads logged
5. **Read-Only Mounts**: Where possible (debugfs, modules)
6. **No External Access**: Unix socket only, no network exposure
7. **ServiceAccount Binding**: Explicit SCC assignment
8. **eBPF Verifier**: Kernel verifier prevents unsafe operations

### Risk Assessment

**Risk Level**: Medium

**Risks**:
- Privileged container escape
- Kernel crash from buggy eBPF program
- Resource exhaustion
- Unauthorized monitoring

**Mitigations**:
- eBPF verifier prevents unsafe kernel operations
- Resource limits prevent exhaustion
- DaemonSet pattern contains blast radius per node
- Monitoring and alerting on pod failures
- RBAC limits who can create eBPF program CRDs
- Audit logging tracks all program loads

## Approval Request Template
```
Subject: Request for bpfman Deployment with Custom SCC

Team: [Your Team]
Purpose: Advanced observability and security monitoring using eBPF
Environment: [Dev/Staging/Production]

Security Requirements:
- Custom SCC: bpfman-scc (see attached manifest)
- Privileged containers in namespace: bpfman
- Host path mounts: /sys/fs/bpf, /sys/kernel/debug, /lib/modules

Business Justification:
- Enable real-time network monitoring without application changes
- Improve security incident detection capabilities
- Reduce overhead compared to traditional monitoring agents
- Industry-standard technology (used by Cilium, Falco, Datadog)

Testing Completed:
- ✅ Local RHEL 9 validation with Podman
- ✅ SELinux compatibility verified (enforcing mode)
- ✅ Security scanning of container images
- ✅ Resource utilization testing
- ✅ Failure scenario testing

Technical Details:
- Image: registry.redhat.io/bpfman/bpfman:0.5.9
- Deployment: DaemonSet (one pod per node)
- Resource Usage: 128Mi-512Mi RAM, 100m-500m CPU per node
- Network: Unix socket only, no external exposure

Security Controls:
- Dedicated namespace with restricted RBAC
- Resource limits enforced
- Audit logging enabled
- Read-only mounts where possible
- eBPF verifier provides kernel protection

Attachments:
- bpfman-openshift.yaml (full manifest)
- CORPORATE-DEPLOYMENT.md (this document)
- POC test results and logs
```

## Implementation Plan

### Phase 1: Development Environment (Week 1)
**Tasks**:
1. Deploy to dev OpenShift cluster
2. Validate SCC configuration
3. Test eBPF program lifecycle
4. Monitor resource usage
5. Document any issues

**Success Criteria**:
- DaemonSet running on all dev nodes
- No security violations
- Resource usage within limits
- eBPF programs load successfully

### Phase 2: Security Review (Week 2)
**Tasks**:
1. Submit security review request
2. Address security team feedback
3. Conduct penetration testing if required
4. Obtain formal SCC approval

**Deliverables**:
- Security review completion
- Documented risk assessment
- Approved custom SCC

### Phase 3: Staging Deployment (Week 3)
**Tasks**:
1. Deploy to staging environment
2. Monitor for 1 week minimum
3. Performance and stability validation
4. Update runbooks and documentation

**Success Criteria**:
- No incidents for 7 consecutive days
- Performance impact < 1% on nodes
- All monitoring alerts configured

### Phase 4: Production Deployment (Week 4+)
**Tasks**:
1. Deploy to production during maintenance window
2. Rolling deployment per availability zone
3. 24-hour monitoring period
4. Full operational handoff

**Rollback Plan**:
- Delete DaemonSet: `oc delete daemonset bpfman -n bpfman`
- No data loss (eBPF programs are ephemeral)
- No downtime for other workloads

## Operational Considerations

### Monitoring

Monitor these metrics:
- **Pod Health**: Restart count (should be 0)
- **Resource Usage**: Memory < 512Mi, CPU < 500m
- **Program Loads**: Success/failure rate
- **Socket Availability**: `/run/bpfman-sock/bpfman.sock` exists

**Alert Thresholds**:
- Pod restarts > 3 in 1 hour
- Memory usage > 450Mi
- Program load failure rate > 5%

### Troubleshooting

**Pods not starting**:
```bash
oc get events -n bpfman --sort-by='.lastTimestamp'
oc describe pod -n bpfman <pod-name>
oc logs -n bpfman <pod-name>
```

**SCC not applying**:
```bash
oc get pod -n bpfman -o yaml | grep -i scc
oc adm policy who-can use scc bpfman-scc
oc describe scc bpfman-scc
```

**eBPF programs failing to load**:
```bash
oc logs -n bpfman -l app=bpfman --tail=100
oc exec -n bpfman <pod> -- dmesg | grep -i bpf
```

**Socket communication issues**:
```bash
oc exec -n bpfman <pod> -- ls -l /run/bpfman-sock/
oc exec -n bpfman <pod> -- netstat -anp | grep bpfman
```

### Backup and Recovery

**What to backup**:
- YAML manifests (version controlled in Git)
- eBPF program CRD definitions
- Configuration files

**Recovery procedure**:
1. Redeploy from version-controlled manifests
2. eBPF programs are ephemeral (recreate from CRDs)
3. No persistent data to restore
4. Service recovers automatically on pod restart

### Upgrades

**Upgrade Process**:
1. Test new version in dev environment
2. Review release notes for breaking changes
3. Update DaemonSet image tag
4. Rolling update automatically managed by OpenShift
5. Monitor for issues during rollout

**Rollback**:
```bash
oc rollout undo daemonset/bpfman -n bpfman
```

## Compliance Considerations

### Audit Logging

All eBPF program operations are logged:
- Program load events
- Program unload events
- Configuration changes
- Access attempts

**Log Location**: OpenShift audit logs + bpfman pod logs

### Data Privacy

- **Network Traffic**: eBPF can inspect packets (read-only)
- **Process Data**: Can observe system calls
- **Mitigation**: Programs reviewed before deployment
- **Compliance**: Follow data handling policies

### Change Management

All eBPF program deployments follow standard change management:
1. Change ticket required
2. Peer review of program code
3. Testing in non-production
4. Approval from change board
5. Documented rollback plan

## Alternatives Considered

| Alternative | Pros | Cons | Decision |
|-------------|------|------|----------|
| Traditional monitoring agents | No privileged access needed | High overhead, limited visibility | Rejected - insufficient capability |
| Sidecar containers | Better isolation | Doesn't work for node-level monitoring | Rejected - wrong use case |
| DTrace/SystemTap | Established tools | Higher overhead, less safe than eBPF | Rejected - eBPF is modern standard |
| Do nothing | No security review needed | Missing critical observability | Rejected - business need exists |

**Why eBPF/bpfman**:
- Industry standard (Linux kernel native)
- Lower overhead than alternatives
- Safer than traditional kernel modules
- Used by major vendors (Cilium, Falco, Datadog)
- Red Hat supported solution

## Cost-Benefit Analysis

### Costs
- Security review time: ~40 hours
- Implementation time: ~80 hours
- Ongoing maintenance: ~10 hours/month
- Compute resources: ~128Mi-512Mi RAM per node

### Benefits
- Real-time network visibility
- Faster incident response
- Reduced monitoring overhead vs. traditional agents
- Better security posture
- Foundation for future eBPF-based tools

**ROI**: Positive within 6 months through reduced incident response time and improved observability.

## References

- [bpfman Documentation](https://bpfman.io)
- [OpenShift SCC Documentation](https://docs.openshift.com/container-platform/latest/authentication/managing-security-context-constraints.html)
- [eBPF Security Best Practices](https://ebpf.io/what-is-ebpf/#security)
- [Kubernetes DaemonSet Guide](https://kubernetes.io/docs/concepts/workloads/controllers/daemonset/)
- [Red Hat bpfman Container Catalog](https://catalog.redhat.com/software/containers/search?q=bpfman)

## Appendix: Example eBPF Program CRD
```yaml
apiVersion: bpfman.io/v1alpha1
kind: XdpProgram
metadata:
  name: xdp-packet-counter
  namespace: bpfman
spec:
  bpffunctionname: xdp_stats
  bytecode:
    image:
      url: quay.io/bpfman-bytecode/xdp_pass:latest
  interfaceselector:
    primarynodeinterface: true
  priority: 50
```

## Contact

**Technical Lead**: Ben Morris
**Team**: SRECore
**Email**: bensan.morris@googlemail.com

---

**Document Version**: 1.0
**Last Updated**: January 5, 2026
**Next Review**: Quarterly
