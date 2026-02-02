# Memory Optimization Guide for i3 Systems

## Overview

This guide provides detailed memory optimization strategies for running the Deception System on Intel i3 processors with 8GB RAM.

## System Requirements

### Minimum (Light Profile)
- RAM: 4GB total (2GB for workloads)
- CPU: 2 cores
- Storage: 10GB

### Recommended (Medium Profile)
- RAM: 8GB total (5-6GB for workloads)
- CPU: 4 cores
- Storage: 20GB SSD

### Production (Heavy Profile)
- RAM: 16GB+ total
- CPU: 6+ cores
- Storage: 50GB+ SSD

## Memory Allocation Strategy

### For 8GB System (Medium Profile)

```
Total RAM: 8GB
├── Operating System: 1.5GB
├── Kubernetes (kubelet, containerd): 1GB
├── Available for Workloads: 5.5GB
│   ├── Honeypots (4x128MB): 512MB
│   ├── Operator: 128MB
│   ├── Prometheus: 512MB
│   ├── Loki: 256MB
│   ├── Grafana: 256MB
│   ├── Weave Scope: 384MB
│   └── Buffer: ~3.5GB for peaks
```

## Optimization Techniques

### 1. Go Runtime Tuning (Operator)

```bash
# Reduce garbage collection frequency
GOGC=50  # Default is 100

# Limit parallelism
GOMAXPROCS=2  # Match CPU cores
```

### 2. Prometheus Optimization

```yaml
# prometheus.yaml
global:
  scrape_interval: 30s  # Increase from 15s
  evaluation_interval: 30s

# Limit query complexity
query.max-samples: 50000
query.timeout: 30s

# Reduce retention
storage.tsdb.retention.time: 24h
storage.tsdb.retention.size: 5GB
```

### 3. Loki Optimization

```yaml
# loki-config.yaml
ingester:
  chunk_idle_period: 2h
  max_chunk_age: 2h
  chunk_block_size: 262144  # 256KB

# Disable WAL for memory savings
wal:
  enabled: false

limits_config:
  max_entries_limit_per_query: 5000
```

### 4. Weave Scope Optimization

```yaml
# Reduce polling frequency
probe.spy.interval: 5s  # Instead of 1s
probe.publish.interval: 10s

# Disable expensive features
--probe.no-controls
```

### 5. Python Honeypot Optimization

```python
# Use asyncio for low memory footprint
# Limit connection buffers
limit=1024 * 64  # 64KB per connection

# Implement connection pooling
max_connections = 50  # Cap concurrent connections
```

## Kubernetes Resource Management

### LimitRange for Automatic Defaults

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: memory-limits
spec:
  limits:
  - default:
      memory: 256Mi
    defaultRequest:
      memory: 64Mi
    type: Container
```

### ResourceQuota for Namespace Limits

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: deception-quota
spec:
  hard:
    requests.memory: 2Gi
    limits.memory: 6Gi
```

## Monitoring Memory Usage

### Real-time Monitoring

```bash
# Watch pod memory usage
watch kubectl top pods -n deception-system

# Check node memory
kubectl describe node | grep -A5 "Allocated resources"

# View container memory stats
kubectl exec -it <pod> -- cat /sys/fs/cgroup/memory/memory.usage_in_bytes
```

### Alerting

```yaml
# Alert when memory > 80%
- alert: HighMemoryUsage
  expr: container_memory_usage_bytes / container_spec_memory_limit_bytes > 0.8
  for: 5m
```

## Swap Configuration

For development environments, you can enable swap:

```bash
# Create swap file
sudo fallocate -l 2G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile

# Configure kubelet to allow swap (k8s 1.28+)
# Add to kubelet config:
featureGates:
  NodeSwap: true
memorySwap:
  swapBehavior: LimitedSwap
```

## Profile Comparison

| Metric | Light | Medium | Heavy |
|--------|-------|--------|-------|
| Total Memory Budget | 1GB | 2.5GB | 6GB |
| Honeypot Memory (each) | 64MB | 128MB | 256MB |
| Prometheus Retention | 6h | 24h | 7d |
| Scrape Interval | 60s | 30s | 15s |
| Weave Scope | Disabled | Optimized | Full |
| E-commerce Demo | Disabled | Enabled | HA |

## Troubleshooting

### OOMKilled Pods

```bash
# Check for OOM events
kubectl get events --field-selector reason=OOMKilled

# Increase limits or reduce workload
kubectl edit deployment <name>
```

### Slow Performance

1. Check CPU throttling: `kubectl top pods`
2. Verify no swap thrashing: `free -h`
3. Consider upgrading to Heavy profile

### Memory Leaks

```bash
# Monitor memory over time
kubectl top pods -n deception-system --containers | while read line; do
  echo "$(date): $line" >> /tmp/memory.log
done
```
