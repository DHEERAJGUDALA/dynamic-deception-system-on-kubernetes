# Weave Scope Memory Optimization Guide

## Overview

This document describes how to optimize Weave Scope for low-specification systems like Intel i3 laptops with 8GB RAM.

## Key Optimizations

### 1. Reduced Polling Intervals

Instead of real-time updates, we use polling:
- `probe.spy.interval=5s` - How often to collect data
- `probe.publish.interval=10s` - How often to publish to app

### 2. Disabled Controls

The `--probe.no-controls` flag disables interactive controls, saving memory.

### 3. Reduced History

The app retains less historical data to reduce memory usage.

### 4. Resource Limits

| Component | Memory Request | Memory Limit | CPU Request | CPU Limit |
|-----------|---------------|--------------|-------------|-----------|
| App       | 192Mi         | 384Mi        | 100m        | 400m      |
| Agent     | 64Mi          | 128Mi        | 50m         | 200m      |

## Profile-Specific Configurations

### Light Profile (4GB total)
- Disable Weave Scope or use minimal configuration
- `probe.spy.interval=15s`
- App memory limit: 256Mi

### Medium Profile (6GB budget, i3 optimized)
- Default configuration in this directory
- Balanced between features and resources

### Heavy Profile (8GB+)
- Enable all features
- `probe.spy.interval=1s`
- App memory limit: 512Mi

## Accessing Weave Scope

```bash
# Port forward to access UI
kubectl -n weave port-forward svc/weave-scope-app 4040:80

# Open in browser
open http://localhost:4040
```

## Troubleshooting

### High Memory Usage

1. Increase polling intervals
2. Reduce retained history
3. Disable Docker probe if not needed

### Slow UI Response

1. Check agent resource limits
2. Verify network connectivity
3. Check for too many pods in cluster

## Alternative: Disable for Light Profile

For very resource-constrained environments, consider disabling Weave Scope entirely and relying on Grafana dashboards for visualization.
