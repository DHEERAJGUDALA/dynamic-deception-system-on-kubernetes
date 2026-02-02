# Dynamic Deception System - Demonstration Guide

## Overview

This guide walks you through deploying and demonstrating a Kubernetes-based honeypot deception system. The system includes:

- **Honeypots**: SSH, HTTP, and MySQL decoys that detect and log attacks
- **Monitoring**: Prometheus metrics and Weave Scope visualization
- **Operator**: Kubernetes controller managing honeypot lifecycle

```
┌─────────────────────────────────────────────────────────────────┐
│                    SYSTEM ARCHITECTURE                          │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│    ┌─────────┐    ┌─────────┐    ┌─────────┐    ┌─────────┐   │
│    │   SSH   │    │  HTTP   │    │  MySQL  │    │  SMTP   │   │
│    │Honeypot │    │Honeypot │    │Honeypot │    │Honeypot │   │
│    │  :2222  │    │  :8080  │    │  :3306  │    │  :25    │   │
│    └────┬────┘    └────┬────┘    └────┬────┘    └────┬────┘   │
│         │              │              │              │         │
│         └──────────────┴──────────────┴──────────────┘         │
│                              │                                  │
│                    ┌─────────▼─────────┐                       │
│                    │     Operator      │                       │
│                    │  (Controller)     │                       │
│                    └─────────┬─────────┘                       │
│                              │                                  │
│              ┌───────────────┼───────────────┐                 │
│              │               │               │                 │
│       ┌──────▼──────┐ ┌──────▼──────┐ ┌──────▼──────┐        │
│       │ Prometheus  │ │   Grafana   │ │ Weave Scope │        │
│       │  (Metrics)  │ │ (Dashboard) │ │ (Topology)  │        │
│       └─────────────┘ └─────────────┘ └─────────────┘        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required Software

```bash
# Check if required tools are installed
docker --version      # Docker 20.10+
minikube version      # Minikube 1.25+
kubectl version       # Kubectl 1.24+
```

### System Requirements

| Profile | RAM    | CPUs | Use Case                    |
|---------|--------|------|-----------------------------|
| Light   | 4GB    | 2    | Basic demo, limited RAM     |
| Medium  | 6GB    | 2    | Recommended for i3 systems  |
| Heavy   | 8GB+   | 4    | Full features, production   |

---

## Part 1: Initial Setup

### Step 1.1: Start Minikube Cluster

```bash
# For systems with limited RAM (4-6GB available)
minikube start --memory=2048 --cpus=2 --driver=docker

# For systems with more RAM (8GB+)
minikube start --memory=4096 --cpus=4 --driver=docker

# Verify cluster is running
kubectl cluster-info
```

### Step 1.2: Configure Docker Environment

```bash
# Point Docker CLI to Minikube's Docker daemon
eval $(minikube docker-env)

# Verify (should show minikube containers)
docker ps | head -5
```

---

## Part 2: Build Honeypot Images

### Step 2.1: Build All Honeypot Images

```bash
cd /home/dh33r4j/projects/dynamic-deception-system

# Build SSH Honeypot
docker build -t ssh-honeypot:latest ./honeypots/ssh/

# Build HTTP Honeypot
docker build -t http-honeypot:latest ./honeypots/http/

# Build Database Honeypot
docker build -t db-honeypot:latest ./honeypots/database/

# Verify images are built
docker images | grep honeypot
```

Expected output:
```
ssh-honeypot      latest    abc123...   Just now    150MB
http-honeypot     latest    def456...   Just now    145MB
db-honeypot       latest    ghi789...   Just now    148MB
```

---

## Part 3: Deploy the Deception System

### Step 3.1: Choose Your Profile

```bash
# Option A: Light profile (4GB RAM systems)
./scripts/setup-light.sh

# Option B: Medium profile (6GB RAM systems) - RECOMMENDED
./scripts/setup-medium.sh

# Option C: Heavy profile (8GB+ RAM systems)
./scripts/setup-heavy.sh
```

### Step 3.2: Manual Deployment (Alternative)

If scripts fail, deploy manually:

```bash
# Create namespace
kubectl apply -f configs/light/namespace.yaml

# Deploy honeypots
kubectl apply -f configs/light/honeypots.yaml

# Deploy monitoring
kubectl apply -f monitoring/prometheus/
```

### Step 3.3: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n deception-system

# Expected output:
# NAME                            READY   STATUS    RESTARTS   AGE
# ssh-honeypot-xxxxx              1/1     Running   0          1m
# http-honeypot-xxxxx             1/1     Running   0          1m
# db-honeypot-xxxxx               1/1     Running   0          1m

# Check services
kubectl get svc -n deception-system
```

---

## Part 4: Deploy Weave Scope (Visualization)

### Step 4.1: Deploy Weave Scope

```bash
# Deploy Scope components
kubectl apply -f k8s/weave-scope/

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=weave-scope -n weave --timeout=120s
```

### Step 4.2: Apply Topology Labels

```bash
# Apply labels for visual distinction in Scope
./scripts/apply-scope-labels.sh
```

### Step 4.3: Access Weave Scope UI

```bash
# Option A: Port-forward (recommended)
kubectl port-forward svc/weave-scope 4040:80 -n weave &

# Open in browser
echo "Open: http://localhost:4040"

# Option B: NodePort
minikube service weave-scope -n weave --url
```

---

## Part 5: Attack Demonstrations

### Demo 1: SSH Brute Force Attack

```bash
# Get SSH honeypot service
kubectl port-forward svc/ssh-honeypot 2222:2222 -n deception-system &

# Simulate SSH brute force (multiple failed logins)
for user in root admin ubuntu pi; do
    for pass in password 123456 admin root; do
        echo "Trying $user:$pass"
        sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o ConnectTimeout=2 \
            $user@localhost -p 2222 2>/dev/null || true
    done
done

# View honeypot logs
kubectl logs -n deception-system deployment/ssh-honeypot --tail=20
```

**What to observe:**
- Each login attempt is logged with username/password
- Source IP is captured
- Timestamps for forensic analysis

### Demo 2: HTTP Web Attacks

```bash
# Get HTTP honeypot service
kubectl port-forward svc/http-honeypot 8080:8080 -n deception-system &

# SQL Injection attacks
curl "http://localhost:8080/login?user=admin'--&pass=x"
curl "http://localhost:8080/search?q=1' OR '1'='1"
curl "http://localhost:8080/api?id=1; DROP TABLE users--"

# Path Traversal attacks
curl "http://localhost:8080/../../../../etc/passwd"
curl "http://localhost:8080/..%2f..%2f..%2fetc/shadow"

# Admin Panel Discovery
curl "http://localhost:8080/admin"
curl "http://localhost:8080/wp-admin"
curl "http://localhost:8080/phpmyadmin"
curl "http://localhost:8080/.git/config"
curl "http://localhost:8080/.env"

# XSS attacks
curl "http://localhost:8080/comment?text=<script>alert(1)</script>"

# View logs
kubectl logs -n deception-system deployment/http-honeypot --tail=30
```

**What to observe:**
- Attack type classification (sql_injection, path_traversal, xss, reconnaissance)
- Full request details (method, path, headers, body)
- Severity ratings

### Demo 3: Database Probing

```bash
# Get MySQL honeypot service
kubectl port-forward svc/db-honeypot 3306:3306 -n deception-system &

# MySQL connection attempts
mysql -h 127.0.0.1 -P 3306 -u root -ppassword 2>/dev/null || true
mysql -h 127.0.0.1 -P 3306 -u admin -padmin123 2>/dev/null || true
mysql -h 127.0.0.1 -P 3306 -u sa -p'' 2>/dev/null || true

# Using netcat for raw probing
echo "SELECT @@version" | nc localhost 3306

# View logs
kubectl logs -n deception-system deployment/db-honeypot --tail=20
```

**What to observe:**
- Connection attempts with credentials
- MySQL protocol handshake captured
- Query attempts logged

### Demo 4: Internal Lateral Movement Simulation

```bash
# Create an "attacker" pod inside the cluster
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: attacker
  namespace: deception-system
  labels:
    app: attacker
    scope.weave.works/role: attacker
    scope.weave.works/risk: malicious
spec:
  containers:
  - name: attacker
    image: curlimages/curl:latest
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: "10m"
        memory: "32Mi"
      limits:
        cpu: "50m"
        memory: "64Mi"
EOF

# Wait for attacker pod
kubectl wait --for=condition=Ready pod/attacker -n deception-system --timeout=60s

# Launch internal attacks
kubectl exec -n deception-system attacker -- curl -s "http://http-honeypot:8080/admin"
kubectl exec -n deception-system attacker -- curl -s "http://http-honeypot:8080/?id=1'+OR+'1'='1"
kubectl exec -n deception-system attacker -- sh -c "nc -w 2 db-honeypot 3306 < /dev/null"
kubectl exec -n deception-system attacker -- sh -c "nc -w 2 ssh-honeypot 2222 < /dev/null"

# View in Weave Scope - you'll see connections from attacker to honeypots
echo "Open http://localhost:4040 to see attack topology"
```

---

## Part 6: Monitoring & Visualization

### 6.1: View in Weave Scope

1. Open http://localhost:4040
2. Click **"Pods"** view
3. Look for pods labeled with:
   - `scope.weave.works/role: honeypot` (honeypots)
   - `scope.weave.works/role: attacker` (attacker pod)
4. Click on connections between pods
5. Use filters:
   - `label:scope.weave.works/role:honeypot` - show only honeypots
   - `label:scope.weave.works/category:deception` - show deception layer

### 6.2: View Prometheus Metrics

```bash
# Port-forward Prometheus
kubectl port-forward svc/prometheus 9090:9090 -n monitoring &

# Open http://localhost:9090

# Sample queries:
# - honeypot_connections_total
# - honeypot_attacks_by_type
# - rate(honeypot_connections_total[5m])
```

### 6.3: View Honeypot Logs

```bash
# Real-time log streaming
kubectl logs -f -n deception-system deployment/ssh-honeypot
kubectl logs -f -n deception-system deployment/http-honeypot
kubectl logs -f -n deception-system deployment/db-honeypot

# All honeypot logs combined
kubectl logs -n deception-system -l component=honeypot --tail=50
```

---

## Part 7: Cleanup

### 7.1: Remove Attacker Pod

```bash
kubectl delete pod attacker -n deception-system --ignore-not-found
```

### 7.2: Full Cleanup

```bash
# Delete all resources
kubectl delete namespace deception-system
kubectl delete namespace monitoring
kubectl delete namespace weave

# Stop minikube
minikube stop

# Delete cluster completely (optional)
minikube delete
```

---

## Quick Reference Commands

```bash
# Status check
kubectl get pods -A | grep -E "(deception|monitoring|weave)"

# View all honeypot logs
kubectl logs -n deception-system -l component=honeypot

# Restart honeypots
kubectl rollout restart deployment -n deception-system

# Port forwards (run in background)
kubectl port-forward svc/ssh-honeypot 2222:2222 -n deception-system &
kubectl port-forward svc/http-honeypot 8080:8080 -n deception-system &
kubectl port-forward svc/db-honeypot 3306:3306 -n deception-system &
kubectl port-forward svc/weave-scope 4040:80 -n weave &
kubectl port-forward svc/prometheus 9090:9090 -n monitoring &

# Kill all port-forwards
pkill -f "port-forward"
```

---

## Troubleshooting

### Pods stuck in ImagePullBackOff

```bash
# Ensure you're using minikube's Docker
eval $(minikube docker-env)

# Rebuild images
docker build -t ssh-honeypot:latest ./honeypots/ssh/
docker build -t http-honeypot:latest ./honeypots/http/
docker build -t db-honeypot:latest ./honeypots/database/

# Patch deployments to use local images
kubectl patch deployment ssh-honeypot -n deception-system \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"ssh-honeypot","imagePullPolicy":"Never"}]}}}}'
```

### Weave Scope not showing data

```bash
# Check agent logs
kubectl logs -n weave daemonset/weave-scope-agent --tail=20

# Restart Scope components
kubectl rollout restart deployment/weave-scope -n weave
kubectl rollout restart daemonset/weave-scope-agent -n weave
```

### Port-forward dies

```bash
# Use nohup to keep it running
nohup kubectl port-forward svc/weave-scope 4040:80 -n weave > /dev/null 2>&1 &
```

### Resource quota errors

```bash
# Check quota usage
kubectl describe resourcequota -n deception-system

# Reduce resource requests in pod specs if needed
```

---

## Demo Script (5-Minute Presentation)

```bash
#!/bin/bash
# Quick 5-minute demo script

echo "=== DYNAMIC DECEPTION SYSTEM DEMO ==="

# 1. Show running honeypots
echo -e "\n[1/5] Honeypots Running:"
kubectl get pods -n deception-system -l component=honeypot

# 2. Show Weave Scope
echo -e "\n[2/5] Opening Weave Scope visualization..."
kubectl port-forward svc/weave-scope 4040:80 -n weave &
sleep 2
echo "Open: http://localhost:4040"

# 3. Launch attacks
echo -e "\n[3/5] Simulating attacks..."
kubectl port-forward svc/http-honeypot 8080:8080 -n deception-system &
sleep 2
curl -s "http://localhost:8080/admin" > /dev/null
curl -s "http://localhost:8080/?id=1'+OR+'1'='1" > /dev/null
echo "Attacks sent!"

# 4. Show logs
echo -e "\n[4/5] Attack logs:"
kubectl logs -n deception-system deployment/http-honeypot --tail=10

# 5. Summary
echo -e "\n[5/5] Demo complete!"
echo "- Honeypots detected SQL injection and reconnaissance"
echo "- View topology at http://localhost:4040"
echo "- Check Prometheus at http://localhost:9090"
```

---

## Architecture Details

### Honeypot Types

| Honeypot | Port | Emulates | Detects |
|----------|------|----------|---------|
| SSH | 2222 | OpenSSH 8.9 | Brute force, credential stuffing |
| HTTP | 8080 | Web server | SQLi, XSS, path traversal, recon |
| MySQL | 3306 | MySQL 5.7 | Database probes, credential attacks |
| SMTP | 25 | Mail server | Spam, relay abuse (optional) |

### Labels for Filtering

| Label | Values | Purpose |
|-------|--------|---------|
| `scope.weave.works/role` | honeypot, observer, controller, legitimate, attacker | Component classification |
| `scope.weave.works/type` | ssh, http, mysql, metrics, dashboard | Service type |
| `scope.weave.works/risk` | decoy, protected, infrastructure, malicious | Risk category |
| `scope.weave.works/category` | deception, monitoring, application, threat | Functional category |

---

## Next Steps

1. **Add more honeypots**: SMTP, FTP, Redis, Elasticsearch
2. **Integrate alerting**: Connect to Slack/PagerDuty
3. **Add Grafana dashboards**: Visualize attack patterns
4. **Deploy to production**: Use real Kubernetes cluster
5. **Add threat intelligence**: Correlate with known bad IPs
