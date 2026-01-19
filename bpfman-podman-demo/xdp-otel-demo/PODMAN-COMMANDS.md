# Podman Commands Cheat Sheet - RHEL9

## Container Management

```bash
# Start all services
podman-compose up -d

# Stop all services
podman-compose down

# Stop and remove volumes
podman-compose down -v

# Restart a specific service
podman-compose restart otel-collector

# View running containers
podman ps
podman-compose ps

# View all containers (including stopped)
podman ps -a
```

## Logs and Debugging

```bash
# View logs from all services
podman-compose logs

# Follow logs (live tail)
podman-compose logs -f

# View logs for specific service
podman-compose logs otel-collector
podman-compose logs -f grafana

# View last N lines
podman-compose logs --tail=50 prometheus

# Direct podman logs
podman logs otel-collector
podman logs -f --tail=20 grafana
```

## Container Shell Access

```bash
# Execute bash in running container
podman exec -it otel-collector /bin/sh
podman exec -it grafana /bin/bash
podman exec -it prometheus /bin/sh

# Run one-off command
podman exec otel-collector cat /etc/otel-collector-config.yaml
```

## Resource Monitoring

```bash
# View container resource usage
podman stats

# One-time snapshot
podman stats --no-stream

# Specific container
podman stats otel-collector

# Detailed container info
podman inspect otel-collector
```

## Image Management

```bash
# List images
podman images

# Pull latest images
podman-compose pull

# Remove unused images
podman image prune

# Remove all images
podman image prune -a
```

## Network Operations

```bash
# List networks
podman network ls

# Inspect network
podman network inspect monitoring

# Test connectivity between containers
podman exec prometheus ping otel-collector

# Check listening ports in container
podman exec otel-collector netstat -tulpn
```

## Volume Management

```bash
# List volumes
podman volume ls

# Inspect volume
podman volume inspect prometheus-data

# Remove unused volumes
podman volume prune

# Backup volume
podman volume export prometheus-data > prometheus-backup.tar

# Restore volume
podman volume import prometheus-data < prometheus-backup.tar
```

## System Cleanup

```bash
# Remove stopped containers
podman container prune

# Remove unused images
podman image prune

# Remove unused volumes
podman volume prune

# Clean everything (careful!)
podman system prune -a --volumes

# See disk usage
podman system df
```

## Rootless vs Rootful

```bash
# Run as regular user (rootless)
podman-compose up -d

# Run as root (rootful)
sudo podman-compose up -d

# Check if running rootless
podman info | grep rootless

# Enable user systemd services
systemctl --user enable --now podman.socket
```

## Systemd Integration

```bash
# Generate systemd unit from container
podman generate systemd --new --name otel-collector > otel-collector.service

# Install user service
mkdir -p ~/.config/systemd/user/
mv otel-collector.service ~/.config/systemd/user/
systemctl --user daemon-reload
systemctl --user enable --now otel-collector

# View service status
systemctl --user status otel-collector

# View service logs
journalctl --user -u otel-collector -f
```

## Port Management

```bash
# List port mappings
podman port otel-collector

# Test if port is accessible
nc -zv localhost 4317
curl -v http://localhost:9090/-/healthy

# Check what's using a port
sudo ss -tulpn | grep :3000
```

## Troubleshooting Commands

```bash
# Check Podman version
podman version

# View system info
podman info

# Check for Podman updates
sudo dnf update podman podman-compose

# View Podman events
podman events

# Health check
podman healthcheck run otel-collector

# Inspect container config
podman inspect otel-collector | jq '.[0].Config'
```

## SELinux Context

```bash
# Check file context
ls -Z otel-collector-config.yaml

# Set correct context
chcon -t container_file_t otel-collector-config.yaml

# Restore default contexts
restorecon -v otel-collector-config.yaml

# Check for SELinux denials
sudo ausearch -m avc -ts recent
```

## Common Workflows

### Restart After Config Change
```bash
# Edit config file
vim otel-collector-config.yaml

# Restart service to pick up changes
podman-compose restart otel-collector

# Verify it's running
podman-compose ps
podman-compose logs otel-collector
```

### Update All Images
```bash
# Pull latest images
podman-compose pull

# Recreate containers with new images
podman-compose up -d

# Remove old images
podman image prune
```

### Full Reset
```bash
# Stop and remove everything
podman-compose down -v

# Remove all images
podman image prune -a

# Start fresh
podman-compose up -d
```

### Backup Configuration
```bash
# Backup all config files
tar -czf xdp-otel-backup-$(date +%Y%m%d).tar.gz \
    *.yaml *.yml *.py *.sh *.md

# Backup Prometheus data
podman run --rm \
    -v prometheus-data:/data \
    -v $(pwd):/backup \
    alpine tar -czf /backup/prometheus-data.tar.gz /data
```

## Performance Tuning

```bash
# Limit CPU and memory
podman run -d \
    --cpus=1.0 \
    --memory=512m \
    otel/opentelemetry-collector

# Use host network for better performance
podman run -d --network=host otel-collector

# Adjust log driver
podman run -d --log-driver=journald otel-collector
```

## Registry Configuration

```bash
# Check registry config
cat /etc/containers/registries.conf

# Search for image in registries
podman search prometheus

# Login to registry
podman login registry.redhat.io
podman login quay.io
```

## Useful Aliases

Add to `~/.bashrc`:

```bash
# Podman aliases
alias pc='podman-compose'
alias pcu='podman-compose up -d'
alias pcd='podman-compose down'
alias pcl='podman-compose logs -f'
alias pcp='podman-compose ps'
alias pcr='podman-compose restart'

# Podman shortcuts
alias pps='podman ps'
alias plog='podman logs -f'
alias pstats='podman stats --no-stream'
alias pprune='podman system prune -a'
```

Reload: `source ~/.bashrc`

Usage:
```bash
pcu          # Start services
pcl          # Follow all logs
pcp          # List services
pcr grafana  # Restart grafana
pstats       # Resource usage
```
