# Dynamic Deception System - Complete Demonstration Guide

## Table of Contents
1. [Overview](#overview)
2. [Prerequisites](#prerequisites)
3. [Quick Start (5 Minutes)](#quick-start-5-minutes)
4. [Full Setup Guide](#full-setup-guide)
5. [Running the Demo](#running-the-demo)
6. [Attack Demonstrations](#attack-demonstrations)
7. [Viewing Results in Weave Scope](#viewing-results-in-weave-scope)
8. [Troubleshooting](#troubleshooting)
9. [Cleanup](#cleanup)

---

## Overview

This project demonstrates a **Kubernetes-based honeypot deception system** that:
- Deploys fake services (honeypots) that look like real infrastructure
- Detects and logs attacks in real-time
- Visualizes the attack topology using Weave Scope
- Distinguishes between legitimate services and decoys

### System Components

```
┌─────────────────────────────────────────────────────────────────────────┐
│                         SYSTEM ARCHITECTURE                              │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                          │
│  🔴 ATTACKER                                                             │
│      │                                                                   │
│      ▼                                                                   │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                      DECEPTION LAYER (Honeypots)                    │ │
│  │                                                                     │ │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │ │
│  │   │  🍯 SSH      │  │  🍯 HTTP     │  │  🍯 MySQL    │            │ │
│  │   │  Honeypot    │  │  Honeypot    │  │  Honeypot    │            │ │
│  │   │  Port 2222   │  │  Port 8080   │  │  Port 3306   │            │ │
│  │   └──────────────┘  └──────────────┘  └──────────────┘            │ │
│  │                                                                     │ │
│  │   Detects: Brute    Detects: SQLi,   Detects: DB                  │ │
│  │   force, cred       XSS, Path Trav,  probing, cred                │ │
│  │   stuffing          Recon, Scanning  attacks                       │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                    LEGITIMATE SERVICES (E-Commerce)                 │ │
│  │                                                                     │ │
│  │   ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐         │ │
│  │   │ ✓ Front  │  │ ✓ API    │  │ ✓ Product│  │ ✓ Order  │         │ │
│  │   │   end    │  │ Gateway  │  │ Service  │  │ Service  │         │ │
│  │   └──────────┘  └──────────┘  └──────────┘  └──────────┘         │ │
│  │                        │                                           │ │
│  │                  ┌─────▼─────┐                                    │ │
│  │                  │ ✓ Postgres│                                    │ │
│  │                  │  Database │                                    │ │
│  │                  └───────────┘                                    │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
│  ┌────────────────────────────────────────────────────────────────────┐ │
│  │                         MONITORING LAYER                            │ │
│  │                                                                     │ │
│  │   ┌──────────────┐  ┌──────────────┐  ┌──────────────┐            │ │
│  │   │ 👁️ Weave     │  │ 👁️ Prometheus│  │ 👁️ Scope    │            │ │
│  │   │   Scope UI   │  │   Metrics    │  │   Agent     │            │ │
│  │   └──────────────┘  └──────────────┘  └──────────────┘            │ │
│  └────────────────────────────────────────────────────────────────────┘ │
│                                                                          │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required Software

| Software | Minimum Version | Check Command |
|----------|-----------------|---------------|
| Docker | 20.10+ | `docker --version` |
| Minikube | 1.25+ | `minikube version` |
| kubectl | 1.24+ | `kubectl version --client` |

### System Requirements

| Profile | RAM | CPUs | Best For |
|---------|-----|------|----------|
| Light | 4GB | 2 | Limited resources, basic demo |
| Medium | 6GB | 2 | **Recommended** for most systems |
| Heavy | 8GB+ | 4 | Full features, presentations |

---

## Quick Start (5 Minutes)

If you already have minikube running with the system deployed:

```bash
# 1. Go to project directory
cd /home/dh33r4j/projects/dynamic-deception-system

# 2. Run the interactive demo
./scripts/demo.sh

# 3. Choose option 1 for "Run full demo"

# 4. Open Weave Scope in browser
# http://localhost:4040
```

---

## Full Setup Guide

### Step 1: Start Minikube Cluster

```bash
# For systems with 4-6GB RAM available
minikube start --memory=2048 --cpus=2 --driver=docker

# For systems with 8GB+ RAM available
minikube start --memory=4096 --cpus=4 --driver=docker

# Verify cluster is running
minikube status
kubectl cluster-info
```

### Step 2: Configure Docker Environment

```bash
# Point Docker CLI to Minikube's Docker daemon
# (Required for building images that minikube can use)
eval $(minikube docker-env)

# Verify - should show minikube containers
docker ps | head -5
```

### Step 3: Build Honeypot Images

```bash
cd /home/dh33r4j/projects/dynamic-deception-system

# Build SSH Honeypot
docker build -t ssh-honeypot:latest ./honeypots/ssh/

# Build HTTP Honeypot
docker build -t http-honeypot:latest ./honeypots/http/

# Build Database Honeypot
docker build -t db-honeypot:latest ./honeypots/database/

# Verify images exist
docker images | grep honeypot
```

Expected output:
```
ssh-honeypot      latest    abc123def   10 seconds ago   150MB
http-honeypot     latest    456ghi789   10 seconds ago   145MB
db-honeypot       latest    jkl012mno   10 seconds ago   148MB
```

### Step 4: Deploy the Deception System

```bash
# Option A: Use setup script (recommended)
./scripts/setup-light.sh    # For 4GB RAM
# OR
./scripts/setup-medium.sh   # For 6GB RAM
# OR
./scripts/setup-heavy.sh    # For 8GB+ RAM

# Option B: Manual deployment
kubectl apply -f configs/light/namespace.yaml
kubectl apply -f configs/light/honeypots.yaml
kubectl apply -f k8s/ecommerce/ecommerce-demo.yaml
kubectl apply -f monitoring/prometheus/
```

### Step 5: Deploy Weave Scope

```bash
# Deploy Weave Scope for visualization
kubectl apply -f k8s/weave-scope/

# Apply labels for visual distinction
./scripts/apply-scope-labels.sh

# Wait for pods to be ready
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=weave-scope -n weave --timeout=120s
```

### Step 6: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n deception-system
kubectl get pods -n weave
kubectl get pods -n monitoring

# Expected: All pods should show "Running" status
```

### Step 7: Access Weave Scope UI

```bash
# Start port-forward to Weave Scope
kubectl port-forward svc/weave-scope 4040:80 -n weave &

# Open in browser
echo "Open: http://localhost:4040"
```

---

## Running the Demo

### Option 1: Interactive Demo Script (Recommended)

```bash
./scripts/demo.sh
```

This shows a menu with options:
```
═══════════════════════════════════════════════════════════════════════
                         DEMO OPTIONS
═══════════════════════════════════════════════════════════════════════

   1) Run full demo (recommended)
   2) Show system architecture
   3) Show running components
   4) Launch attack simulation
   5) View honeypot logs
   6) Open Weave Scope
   7) Cleanup and exit

   Select option [1-7]:
```

### Option 2: Full Automatic Demo

```bash
./scripts/demo.sh full
```

Runs the complete demo automatically with pauses between sections.

### Option 3: Quick Attack Demo

```bash
./scripts/demo.sh attack
```

Just runs the attack simulation (useful for repeat demonstrations).

---

## Attack Demonstrations

### Demo 1: SQL Injection Attack

**What it simulates:** An attacker trying to exploit database vulnerabilities through web forms.

```bash
# Manual execution
kubectl exec -n deception-system attacker -- curl -s \
  "http://http-honeypot:8080/login?user=admin'--&pass=x"

kubectl exec -n deception-system attacker -- curl -s \
  "http://http-honeypot:8080/search?q=1' OR '1'='1"

kubectl exec -n deception-system attacker -- curl -s \
  "http://http-honeypot:8080/api?id=1; DROP TABLE users--"
```

**What the honeypot logs:**
```json
{
  "event": "http_request",
  "attack_type": "sql_injection",
  "path": "/login?user=admin'--",
  "source_ip": "10.244.0.33"
}
```

### Demo 2: Path Traversal Attack

**What it simulates:** An attacker trying to access files outside the web root.

```bash
kubectl exec -n deception-system attacker -- curl -s \
  "http://http-honeypot:8080/../../../../etc/passwd"

kubectl exec -n deception-system attacker -- curl -s \
  "http://http-honeypot:8080/..%2f..%2f..%2fetc/shadow"
```

**What the honeypot detects:**
```json
{
  "event": "http_request",
  "attack_type": "path_traversal",
  "path": "/etc/passwd",
  "source_ip": "10.244.0.33"
}
```

### Demo 3: Reconnaissance / Admin Panel Discovery

**What it simulates:** An attacker scanning for common admin panels and sensitive files.

```bash
# Probe for admin panels
kubectl exec -n deception-system attacker -- curl -s "http://http-honeypot:8080/admin"
kubectl exec -n deception-system attacker -- curl -s "http://http-honeypot:8080/wp-admin"
kubectl exec -n deception-system attacker -- curl -s "http://http-honeypot:8080/phpmyadmin"

# Probe for sensitive files
kubectl exec -n deception-system attacker -- curl -s "http://http-honeypot:8080/.git/config"
kubectl exec -n deception-system attacker -- curl -s "http://http-honeypot:8080/.env"
kubectl exec -n deception-system attacker -- curl -s "http://http-honeypot:8080/backup.sql"
```

**What the honeypot logs:**
```json
{
  "event": "http_request",
  "attack_type": "reconnaissance",
  "path": "/wp-admin",
  "source_ip": "10.244.0.33"
}
```

### Demo 4: XSS (Cross-Site Scripting) Attack

**What it simulates:** An attacker injecting malicious JavaScript.

```bash
kubectl exec -n deception-system attacker -- curl -s \
  "http://http-honeypot:8080/search?q=<script>alert(1)</script>"
```

### Demo 5: MySQL Database Probing

**What it simulates:** An attacker trying to connect to a database server.

```bash
# Attempt database connections
for i in 1 2 3 4 5; do
  kubectl exec -n deception-system attacker -- sh -c \
    "nc -w 1 db-honeypot 3306 < /dev/null"
done
```

**What the honeypot logs:**
```json
{
  "event": "connection_opened",
  "protocol": "mysql",
  "source_ip": "10.244.0.33"
}
```

### Demo 6: SSH Brute Force Attack

**What it simulates:** An attacker trying multiple passwords to gain SSH access.

```bash
# Attempt SSH connections
for i in 1 2 3 4 5; do
  kubectl exec -n deception-system attacker -- sh -c \
    "echo 'SSH-2.0-Attacker' | nc -w 1 ssh-honeypot 2222"
done
```

**What the honeypot logs:**
```json
{
  "event": "ssh_connection",
  "client_version": "SSH-2.0-Attacker",
  "source_ip": "10.244.0.33"
}
```

---

## Viewing Results in Weave Scope

### Accessing the UI

```bash
# Ensure port-forward is running
kubectl port-forward svc/weave-scope 4040:80 -n weave &

# Open in browser
open http://localhost:4040
# Or manually navigate to: http://localhost:4040
```

### Navigating the Topology

1. **Select "Pods" View** (top menu)
   - Shows all Kubernetes pods as nodes
   - Connections between pods shown as lines

2. **Identify Components by Labels:**
   - 🍯 **Honeypots** - labeled with `scope.weave.works/role: honeypot`
   - ✓ **E-Commerce** - labeled with `scope.weave.works/role: legitimate`
   - 👁️ **Monitoring** - labeled with `scope.weave.works/role: observer`
   - 🔴 **Attacker** - labeled with `scope.weave.works/role: attacker`

3. **Click on any pod** to see:
   - Resource usage (CPU, Memory)
   - All Kubernetes labels
   - Connection details
   - Process list

### Using Filters

Type these in the search box to filter the view:

| Filter | Shows |
|--------|-------|
| `label:scope.weave.works/role:honeypot` | Only honeypots |
| `label:scope.weave.works/role:legitimate` | Only e-commerce services |
| `label:scope.weave.works/role:attacker` | Only attacker pod |
| `label:scope.weave.works/category:deception` | Deception layer |
| `label:scope.weave.works/category:application` | Application layer |

### What to Look For During Attack Demo

1. **Before Attacks:**
   - Honeypots visible but no connections from attacker
   - E-commerce services connected to each other

2. **During Attacks:**
   - Lines appear from attacker → honeypots
   - Click attacker pod to see outbound connections
   - Click honeypot pod to see incoming connections

3. **Attack Indicators:**
   - Multiple connections to honeypots = suspicious activity
   - Internal pod connecting to honeypot = lateral movement
   - Thick connection lines = high traffic volume

---

## Viewing Honeypot Logs

### Real-Time Log Streaming

```bash
# HTTP Honeypot (shows web attacks)
kubectl logs -f -n deception-system deployment/http-honeypot

# SSH Honeypot (shows login attempts)
kubectl logs -f -n deception-system deployment/ssh-honeypot

# MySQL Honeypot (shows database probes)
kubectl logs -f -n deception-system deployment/db-honeypot
```

### View Recent Logs

```bash
# Last 20 entries from each honeypot
kubectl logs -n deception-system deployment/http-honeypot --tail=20
kubectl logs -n deception-system deployment/ssh-honeypot --tail=20
kubectl logs -n deception-system deployment/db-honeypot --tail=20

# All honeypot logs combined
kubectl logs -n deception-system -l component=honeypot --tail=50
```

### Log Format Examples

**HTTP Honeypot:**
```json
{
  "event": "http_request",
  "session_id": "abc123",
  "method": "GET",
  "path": "/admin",
  "source_ip": "10.244.0.33",
  "user_agent": "curl/8.18.0",
  "attack_type": "reconnaissance"
}
```

**SSH Honeypot:**
```json
{
  "event": "login_attempt",
  "session_id": "def456",
  "username": "root",
  "password": "admin123",
  "source_ip": "10.244.0.33"
}
```

**MySQL Honeypot:**
```json
{
  "event": "connection_opened",
  "session_id": "ghi789",
  "source_ip": "10.244.0.33",
  "protocol": "mysql"
}
```

---

## Troubleshooting

### Problem: Pods stuck in "ImagePullBackOff"

**Solution:** Build images inside minikube's Docker environment.

```bash
# Configure Docker to use minikube's daemon
eval $(minikube docker-env)

# Rebuild images
docker build -t ssh-honeypot:latest ./honeypots/ssh/
docker build -t http-honeypot:latest ./honeypots/http/
docker build -t db-honeypot:latest ./honeypots/database/

# Patch deployments to use local images
kubectl patch deployment ssh-honeypot -n deception-system \
  -p '{"spec":{"template":{"spec":{"containers":[{"name":"ssh-honeypot","imagePullPolicy":"Never"}]}}}}'
```

### Problem: Weave Scope not showing data

**Solution:** Restart Weave Scope components.

```bash
# Check agent logs
kubectl logs -n weave daemonset/weave-scope-agent --tail=20

# Restart components
kubectl rollout restart deployment/weave-scope -n weave
kubectl rollout restart daemonset/weave-scope-agent -n weave

# Wait for restart
kubectl rollout status deployment/weave-scope -n weave
```

### Problem: Port-forward keeps dying

**Solution:** Use nohup or run in background properly.

```bash
# Kill existing port-forwards
pkill -f "port-forward"

# Start with nohup
nohup kubectl port-forward svc/weave-scope 4040:80 -n weave > /dev/null 2>&1 &

# Verify it's running
curl -s http://localhost:4040/api
```

### Problem: "Resource quota exceeded" errors

**Solution:** Use the light profile or reduce resource requests.

```bash
# Check current quota usage
kubectl describe resourcequota -n deception-system

# Use light profile
./scripts/setup-light.sh
```

### Problem: Attacker pod not creating

**Solution:** Create with explicit resource limits.

```bash
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: attacker
  namespace: deception-system
  labels:
    app: attacker
    scope.weave.works/role: attacker
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
```

---

## Cleanup

### Remove Attacker Pod Only

```bash
kubectl delete pod attacker -n deception-system
```

### Stop Port-Forwards

```bash
pkill -f "port-forward"
```

### Full Cleanup (Remove Everything)

```bash
# Delete all namespaces
kubectl delete namespace deception-system
kubectl delete namespace monitoring
kubectl delete namespace weave

# Stop minikube
minikube stop

# Delete cluster completely (optional)
minikube delete
```

### Quick Reset (Keep Cluster, Redeploy)

```bash
# Delete and recreate
kubectl delete namespace deception-system --ignore-not-found
kubectl delete namespace weave --ignore-not-found

# Redeploy
./scripts/setup-light.sh
kubectl apply -f k8s/weave-scope/
./scripts/apply-scope-labels.sh
```

---

## Quick Reference Card

### Essential Commands

```bash
# Start demo
./scripts/demo.sh

# Check status
kubectl get pods -n deception-system
kubectl get pods -n weave

# View logs
kubectl logs -n deception-system deployment/http-honeypot --tail=20

# Access Weave Scope
kubectl port-forward svc/weave-scope 4040:80 -n weave &
# Open: http://localhost:4040

# Run attacks manually
kubectl exec -n deception-system attacker -- curl -s "http://http-honeypot:8080/admin"

# Cleanup
kubectl delete pod attacker -n deception-system
pkill -f "port-forward"
```

### Weave Scope Filters

```
label:scope.weave.works/role:honeypot      # Show honeypots
label:scope.weave.works/role:legitimate    # Show real services
label:scope.weave.works/role:attacker      # Show attacker
label:scope.weave.works/category:deception # Show deception layer
```

### Demo Talking Points

1. **Introduction** - "This is a honeypot deception system for Kubernetes"
2. **Architecture** - "We have 3 honeypots mimicking SSH, HTTP, and MySQL"
3. **Legitimate Services** - "These 5 services represent a real e-commerce app"
4. **Attack Demo** - "Watch as we simulate various attacks..."
5. **Detection** - "The honeypots detected and logged all attacks"
6. **Visualization** - "Weave Scope shows the attack topology in real-time"
7. **Value Proposition** - "Attackers waste time on decoys while we gather intel"

---

## Files Created

| File | Purpose |
|------|---------|
| `./scripts/demo.sh` | Interactive demo script |
| `./scripts/setup-light.sh` | Setup for 4GB RAM systems |
| `./scripts/setup-medium.sh` | Setup for 6GB RAM systems |
| `./scripts/apply-scope-labels.sh` | Apply Weave Scope labels |
| `./k8s/weave-scope/` | Weave Scope Kubernetes configs |
| `./k8s/ecommerce/` | E-commerce service configs |
| `./honeypots/ssh/` | SSH honeypot code |
| `./honeypots/http/` | HTTP honeypot code |
| `./honeypots/database/` | MySQL honeypot code |
| `./DEMO-GUIDE.md` | Quick reference guide |
| `./HOW-TO-DEMO.md` | This comprehensive guide |
