# Podman Troubleshooting Guide for RHEL9

## Common Podman Issues on RHEL9

### Issue: "Error: short-name resolution enforced"

**Symptom:**
```
Error: short-name "grafana" did not resolve to an alias and no unqualified-search registries are configured
```

**Solution:**
Add full registry paths to images, or configure registries:
```bash
# Option 1: Edit /etc/containers/registries.conf
sudo tee -a /etc/containers/registries.conf <<EOF
[registries.search]
registries = ['docker.io', 'quay.io']
EOF

# Option 2: Use full image names in docker-compose.yml
# (Already done in this demo)
```

### Issue: SELinux Permission Denied

**Symptom:**
```
Error: error mounting volume: Permission denied
```

**Solution:**
```bash
# Add :Z suffix to volumes (already in docker-compose.yml)
# OR temporarily set SELinux to permissive for testing
sudo setenforce 0

# To make permanent (NOT recommended for production):
sudo sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config

# Better: Fix SELinux labels
chcon -R -t container_file_t /path/to/xdp-otel-demo/
```

### Issue: "Cannot connect to Podman socket"

**Symptom:**
```
Error: unable to connect to Podman socket
```

**Solution:**
```bash
# Enable and start Podman socket
systemctl --user enable --now podman.socket

# Verify socket
systemctl --user status podman.socket

# Test connection
podman info
```

### Issue: Port Already in Use

**Symptom:**
```
Error: failed to expose port 3000: cannot listen on the TCP port: listen tcp4 0.0.0.0:3000: bind: address already in use
```

**Solution:**
```bash
# Find what's using the port
sudo ss -tulpn | grep :3000

# Either stop the conflicting service or change ports in docker-compose.yml
# Example: Change Grafana to port 3001
ports:
  - "3001:3000"
```

### Issue: Rootless Podman Volume Permissions

**Symptom:**
Containers can't write to volumes

**Solution:**
```bash
# Podman rootless uses user namespaces
# Volumes may need proper ownership

# Option 1: Use named volumes (recommended - already done)
podman volume ls

# Option 2: For bind mounts, adjust ownership
podman unshare chown -R 0:0 /path/to/volume

# Option 3: Use userns_mode: "keep-id" (already in docker-compose.yml)
```

### Issue: cgroup v1 vs v2

**Symptom:**
Warning about cgroup version

**Solution:**
```bash
# RHEL9 uses cgroup v2 by default (good!)
# Verify:
stat -fc %T /sys/fs/cgroup/
# Should output: cgroup2fs

# If showing cgroup v1, upgrade kernel or boot parameters needed
```

### Issue: Podman-compose Not Found

**Symptom:**
```
bash: podman-compose: command not found
```

**Solution:**
```bash
# Install from RHEL repos
sudo dnf install -y podman-compose

# OR install via pip
pip3 install --break-system-packages podman-compose

# Verify installation
podman-compose --version
```

## Podman Best Practices on RHEL9

### 1. Use Rootless Podman (Default)

```bash
# Run as regular user (no sudo needed for containers)
podman-compose up -d

# Check rootless status
podman info | grep rootless
```

### 2. Firewall Configuration

```bash
# If services aren't accessible:
sudo firewall-cmd --add-port=3000/tcp --permanent  # Grafana
sudo firewall-cmd --add-port=9090/tcp --permanent  # Prometheus
sudo firewall-cmd --add-port=4317/tcp --permanent  # OTel gRPC
sudo firewall-cmd --reload
```

### 3. Systemd Integration

```bash
# Generate systemd unit files from compose
podman-compose systemd

# OR manually create service
podman generate systemd --new --name otel-collector > ~/.config/systemd/user/otel-collector.service
systemctl --user daemon-reload
systemctl --user enable --now otel-collector
```

### 4. Resource Limits

```bash
# Check resource usage
podman stats

# Set limits in docker-compose.yml
services:
  otel-collector:
    deploy:
      resources:
        limits:
          cpus: '1.0'
          memory: 512M
```

### 5. Network Troubleshooting

```bash
# List networks
podman network ls

# Inspect network
podman network inspect monitoring

# Test connectivity between containers
podman exec -it prometheus ping otel-collector

# Check if ports are listening
podman exec -it otel-collector netstat -tulpn
```

## Quick Command Reference

```bash
# Start services
podman-compose up -d

# Stop services
podman-compose down

# View logs
podman-compose logs -f otel-collector

# Restart a service
podman-compose restart prometheus

# View running containers
podman ps

# Execute command in container
podman exec -it grafana /bin/bash

# Check resource usage
podman stats --no-stream

# Clean up everything
podman-compose down -v
podman system prune -a

# Update images
podman-compose pull
podman-compose up -d
```

## RHEL9-Specific Considerations

### Subscription Manager
```bash
# Ensure RHEL subscription is active
sudo subscription-manager status

# Enable required repos
sudo subscription-manager repos --enable=rhel-9-for-x86_64-appstream-rpms
```

### Python on RHEL9
```bash
# Use --break-system-packages for pip installs
pip3 install --break-system-packages <package>

# Or use virtual environment (better for production)
python3 -m venv ~/venv
source ~/venv/bin/activate
pip install opentelemetry-sdk
```

### BPF Programs and SELinux

```bash
# BPF programs need special permissions
# If running exporter fails:

# Check audit logs
sudo ausearch -m avc -ts recent

# Allow BPF operations
sudo setsebool -P domain_can_mmap_files 1
```

## Performance Tuning

### For High-Traffic XDP Programs

```bash
# Increase map memory limits
sudo sysctl -w kernel.bpf.maxmemlock=1073741824

# Make permanent
echo "kernel.bpf.maxmemlock = 1073741824" | sudo tee -a /etc/sysctl.conf

# Optimize OTel export interval
python3 xdp_otel_exporter_simple.py --interval 5  # faster exports

# Increase Prometheus retention
# In docker-compose.yml, add to prometheus command:
- '--storage.tsdb.retention.time=30d'
```

## Getting Help

```bash
# Check Podman version
podman version

# View system info
podman info

# Check for updates
sudo dnf update podman podman-compose

# Red Hat support
# For RHEL support: https://access.redhat.com/support
```

## Useful Links

- [Podman on RHEL9 Docs](https://docs.redhat.com/en/documentation/red_hat_enterprise_linux/9/html/building_running_and_managing_containers/)
- [Rootless Podman Guide](https://github.com/containers/podman/blob/main/docs/tutorials/rootless_tutorial.md)
- [SELinux with Containers](https://www.redhat.com/en/blog/using-selinux-and-oci-containers)
