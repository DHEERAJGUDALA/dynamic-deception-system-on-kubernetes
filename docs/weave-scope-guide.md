# Weave Scope Guide for Deception System Visualization

## Overview

Weave Scope provides real-time visualization of your Kubernetes cluster topology. This guide explains how to use Scope to monitor the deception system and distinguish between honeypots and legitimate services.

## Quick Start

```bash
# Deploy Weave Scope
kubectl apply -f k8s/weave-scope/

# Apply labels for visual distinction
./scripts/apply-scope-labels.sh

# Access the UI
kubectl port-forward svc/weave-scope 4040:80 -n weave
# Open: http://localhost:4040
```

## Visual Legend

The deception system uses custom labels to visually distinguish components:

```
┌─────────────────────────────────────────────────────────────────┐
│                    TOPOLOGY LEGEND                               │
├─────────────────────────────────────────────────────────────────┤
│                                                                  │
│   🍯 HONEYPOT (Decoy)                                           │
│   ├── SSH Honeypot     - Captures SSH login attempts            │
│   ├── HTTP Honeypot    - Detects web attacks                    │
│   ├── MySQL Honeypot   - Logs database intrusions               │
│   └── SMTP Honeypot    - Captures email abuse                   │
│                                                                  │
│   ⚙️  CONTROLLER (Infrastructure)                                │
│   └── Deception Operator - Manages honeypot lifecycle           │
│                                                                  │
│   👁️  OBSERVER (Monitoring)                                      │
│   ├── Prometheus       - Metrics collection                     │
│   ├── Grafana          - Dashboards                             │
│   ├── Loki             - Log aggregation                        │
│   └── Weave Scope      - Topology visualization                 │
│                                                                  │
│   ✓ LEGITIMATE (Protected)                                      │
│   ├── Frontend         - User-facing web app                    │
│   ├── API              - Backend services                       │
│   └── Database         - Real data storage                      │
│                                                                  │
└─────────────────────────────────────────────────────────────────┘
```

## Scope UI Navigation

### Main Views

1. **Containers View** - Shows all running containers
   - Filter by namespace: `deception-system`, `monitoring`, `weave`
   - Look for honeypot labels

2. **Pods View** - Kubernetes pod topology
   - Best for seeing deception architecture
   - Click pods to see labels and connections

3. **Hosts View** - Node-level overview
   - Shows resource distribution

### Filtering by Labels

In the Scope UI search box, use these filters:

```
# Show only honeypots
label:scope.weave.works/role:honeypot

# Show only legitimate services
label:scope.weave.works/risk:protected

# Show deception layer
label:scope.weave.works/category:deception

# Show monitoring components
label:scope.weave.works/category:monitoring
```

## Understanding the Topology

### Normal State

```
                    ┌─────────────┐
                    │   Ingress   │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │                 │                 │
         ▼                 ▼                 ▼
   ┌───────────┐    ┌───────────┐    ┌───────────┐
   │    🍯     │    │    🍯     │    │    🍯     │
   │   SSH     │    │   HTTP    │    │  MySQL    │
   │ Honeypot  │    │ Honeypot  │    │ Honeypot  │
   └───────────┘    └───────────┘    └───────────┘
         │                 │                 │
         └─────────────────┼─────────────────┘
                           │
                    ┌──────▼──────┐
                    │     ⚙️      │
                    │  Operator   │
                    └──────┬──────┘
                           │
                    ┌──────▼──────┐
                    │     👁️      │
                    │ Prometheus  │
                    └─────────────┘
```

### During Attack

When an attacker connects to a honeypot, you'll see:

```
   ┌───────────┐
   │ Attacker  │ ←── External connection (red/orange edge)
   │   Pod     │
   └─────┬─────┘
         │
         ▼
   ┌───────────┐
   │    🍯     │ ←── Honeypot receiving traffic
   │   HTTP    │
   │ Honeypot  │
   └───────────┘
```

### Connection Patterns to Watch

| Pattern | Meaning | Severity |
|---------|---------|----------|
| External → 🍯 Honeypot | Attack in progress | ⚠️ Warning |
| Internal → 🍯 Honeypot | Lateral movement | 🔴 Critical |
| 🍯 Honeypot → Internal | Compromised honeypot | 🔴 Critical |
| External → ✓ Legitimate | Normal traffic | ✅ OK |

## Real-Time Monitoring

### What to Look For

1. **New Connections to Honeypots**
   - Any connection to a honeypot is suspicious
   - Scope shows live connection edges

2. **Connection Sources**
   - External IPs connecting to honeypots
   - Internal pods probing honeypots (lateral movement)

3. **Traffic Volume**
   - Sudden spikes to honeypots indicate attacks
   - Scope shows connection thickness based on traffic

### Alert Triggers

Watch for these patterns in Scope:

| Visual Indicator | Meaning |
|-----------------|---------|
| Thick edge to honeypot | High traffic attack |
| Multiple edges to honeypots | Port scanning |
| Edge from legitimate → honeypot | Compromised service |
| New pod connecting to honeypots | Potential malware |

## Demonstration Scenarios

### Scenario 1: SSH Brute Force

```bash
# Simulate attack (from another terminal)
for i in {1..10}; do
  ssh -o ConnectTimeout=2 admin@localhost -p 2222 2>/dev/null &
done
```

**In Scope:** You'll see multiple connection attempts to the SSH honeypot pod.

### Scenario 2: Web Attack

```bash
# Simulate SQL injection
curl "http://localhost:8080/?id=1' OR '1'='1"
curl "http://localhost:8080/admin"
curl "http://localhost:8080/wp-admin"
```

**In Scope:** Watch for connections to the HTTP honeypot with the attack labels visible in pod details.

### Scenario 3: Database Probe

```bash
# Simulate MySQL connection attempt
mysql -h localhost -P 3306 -u root -p 2>/dev/null
```

**In Scope:** See the connection attempt to the MySQL honeypot.

## Resource Optimization

The deployment is optimized for low-resource systems:

| Component | CPU Request | Memory Request | CPU Limit | Memory Limit |
|-----------|-------------|----------------|-----------|--------------|
| Scope App | 50m | 128Mi | 150m | 256Mi |
| Scope Agent | 25m | 64Mi | 100m | 128Mi |

### Reducing Resource Usage Further

```yaml
# In scope-deployment-minimal.yaml, increase intervals:
args:
  - '--probe.spy.interval=120s'    # Less frequent probing
  - '--probe.publish.interval=120s'
  - '--app.window=5m'              # Shorter history
```

## Troubleshooting

### Scope UI Not Loading

```bash
# Check pod status
kubectl get pods -n weave

# Check logs
kubectl logs -n weave deployment/weave-scope
```

### Pods Not Showing in UI

```bash
# Verify agent is running
kubectl get daemonset -n weave

# Check agent logs
kubectl logs -n weave daemonset/weave-scope-agent
```

### Labels Not Visible

```bash
# Re-apply labels
./scripts/apply-scope-labels.sh

# Verify labels
kubectl get pods -n deception-system --show-labels
```

## Screenshots Reference

### Main Topology View
- Shows all pods with connections
- Honeypots appear with 🍯 labels
- Real services marked with ✓

### Pod Detail View
- Click any pod to see:
  - All labels including scope.weave.works/*
  - Resource usage
  - Connection history
  - Process list

### Filter Applied View
- Use search to filter by:
  - `label:scope.weave.works/role:honeypot`
  - Isolates just the deception infrastructure

## Best Practices

1. **Keep Scope Running** - Real-time visibility into attacks
2. **Check Regularly** - Look for unexpected connections
3. **Use Labels** - Filter views to focus on specific components
4. **Combine with Logs** - Cross-reference Scope visuals with honeypot logs
5. **Screenshot Evidence** - Capture attack topology for forensics
