# Dynamic Deception System - Complete Setup & Demo Procedure

## Table of Contents
1. [System Overview](#system-overview)
2. [Architecture](#architecture)
3. [Prerequisites](#prerequisites)
4. [Complete Setup Procedure](#complete-setup-procedure)
5. [Running the Demo](#running-the-demo)
6. [What Happens During Attack](#what-happens-during-attack)
7. [Viewing Results](#viewing-results)
8. [Troubleshooting](#troubleshooting)
9. [Cleanup](#cleanup)
10. [Quick Reference](#quick-reference)

---

## System Overview

This is a **Kubernetes-based honeypot deception system** that:
- Deploys 8 fake services (honeypots) that look like real infrastructure
- Traps attackers in the deception layer
- Logs all attack attempts
- Protects real services by keeping them hidden
- Visualizes attack topology in real-time using Weave Scope

### Components

| Component | Count | Purpose |
|-----------|-------|---------|
| Honeypots | 8 | Fake services to trap attackers |
| Real Services | 3 | Protected e-commerce application |
| Attacker Pod | 1 | Simulates malicious actor |
| Weave Scope | 1 | Real-time topology visualization |
| Prometheus | 1 | Metrics collection |

---

## Architecture

```
                         ATTACKER
                             │
                             │ Scans network, finds "services"
                             ▼
┌─────────────────────────────────────────────────────────────────────────┐
│                      DECEPTION LAYER (Exposed)                          │
│                    Namespace: deception-system                          │
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐│
│  │     🍯       │  │     🍯       │  │     🍯       │  │     🍯       ││
│  │  Frontend    │  │    API       │  │   Admin      │  │   MySQL      ││
│  │  Honeypot    │  │  Honeypot    │  │  Honeypot    │  │  Honeypot    ││
│  │   :80        │  │   :8080      │  │   :8081      │  │   :3306      ││
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘│
│                                                                         │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐│
│  │     🍯       │  │     🍯       │  │     🍯       │  │     🍯       ││
│  │  PostgreSQL  │  │    SSH       │  │   Redis      │  │Elasticsearch ││
│  │  Honeypot    │  │  Honeypot    │  │  Honeypot    │  │  Honeypot    ││
│  │   :5432      │  │   :22        │  │   :6379      │  │   :9200      ││
│  └──────────────┘  └──────────────┘  └──────────────┘  └──────────────┘│
│                                                                         │
│                 ⚡ ALL ATTACKS TRAPPED AND LOGGED HERE ⚡                │
└─────────────────────────────────────────────────────────────────────────┘
                             │
                             ❌ BLOCKED - Attacker cannot reach
                             │
┌─────────────────────────────────────────────────────────────────────────┐
│                     REAL SERVICES (Hidden/Protected)                     │
│                    Namespace: ecommerce-internal                         │
│                                                                         │
│         ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│         │     ✓        │  │     ✓        │  │     ✓        │           │
│         │    Real      │  │    Real      │  │    Real      │           │
│         │  Frontend    │  │    API       │  │  Database    │           │
│         └──────────────┘  └──────────────┘  └──────────────┘           │
│                                                                         │
│                    🔒 PROTECTED - Never exposed to attacker              │
└─────────────────────────────────────────────────────────────────────────┘
                             │
┌─────────────────────────────────────────────────────────────────────────┐
│                         MONITORING LAYER                                 │
│                                                                         │
│         ┌──────────────┐  ┌──────────────┐  ┌──────────────┐           │
│         │     👁️       │  │     👁️       │  │     👁️       │           │
│         │ Weave Scope  │  │  Prometheus  │  │ Scope Agent  │           │
│         │   :4040      │  │   :9090      │  │              │           │
│         └──────────────┘  └──────────────┘  └──────────────┘           │
└─────────────────────────────────────────────────────────────────────────┘
```

---

## Prerequisites

### Required Software

```bash
# Check Docker
docker --version
# Expected: Docker version 20.10+

# Check Minikube
minikube version
# Expected: minikube version: v1.25+

# Check kubectl
kubectl version --client
# Expected: Client Version: v1.24+
```

### System Requirements

| Profile | RAM | CPUs | Recommended For |
|---------|-----|------|-----------------|
| Light | 4GB | 2 | Limited resources |
| Medium | 6GB | 2 | Most laptops (recommended) |
| Heavy | 8GB+ | 4 | Full features |

---

## Complete Setup Procedure

### Step 1: Start Minikube Cluster

```bash
# For systems with 4-6GB RAM
minikube start --memory=2048 --cpus=2 --driver=docker

# For systems with 8GB+ RAM
minikube start --memory=4096 --cpus=4 --driver=docker

# Verify cluster is running
minikube status
kubectl cluster-info
```

### Step 2: Configure Docker Environment

```bash
# Point Docker CLI to Minikube's Docker daemon
# This is REQUIRED for building images that minikube can use
eval $(minikube docker-env)

# Verify - should show minikube containers
docker ps | head -5
```

### Step 3: Navigate to Project Directory

```bash
cd /home/dh33r4j/projects/dynamic-deception-system
```

### Step 4: Build Honeypot Images

```bash
# Build SSH Honeypot
docker build -t deception-system/ssh-honeypot:latest ./honeypots/ssh/

# Build HTTP Honeypot (used for web-based honeypots)
docker build -t deception-system/http-honeypot:latest ./honeypots/http/

# Build Database Honeypot (used for DB-based honeypots)
docker build -t deception-system/db-honeypot:latest ./honeypots/database/

# Verify images exist
docker images | grep deception-system
```

Expected output:
```
deception-system/ssh-honeypot    latest    abc123...   10 seconds ago
deception-system/http-honeypot   latest    def456...   10 seconds ago
deception-system/db-honeypot     latest    ghi789...   10 seconds ago
```

### Step 5: Create Namespaces

```bash
# Create deception-system namespace (if not exists)
kubectl create namespace deception-system --dry-run=client -o yaml | kubectl apply -f -

# Create monitoring namespace
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Create weave namespace
kubectl create namespace weave --dry-run=client -o yaml | kubectl apply -f -
```

### Step 6: Deploy the 8 Honeypots

```bash
# Deploy all honeypots
kubectl apply -f k8s/deception-layer/honeypots-full.yaml

# Wait for honeypots to be ready
kubectl wait --for=condition=Ready pods -l component=honeypot -n deception-system --timeout=120s

# Verify all 8 honeypots are running
kubectl get pods -n deception-system -l component=honeypot
```

Expected output:
```
NAME                                      READY   STATUS    RESTARTS   AGE
admin-honeypot-xxxxx                      1/1     Running   0          1m
api-honeypot-xxxxx                        1/1     Running   0          1m
elasticsearch-honeypot-xxxxx              1/1     Running   0          1m
frontend-honeypot-xxxxx                   1/1     Running   0          1m
mysql-honeypot-xxxxx                      1/1     Running   0          1m
postgres-honeypot-xxxxx                   1/1     Running   0          1m
redis-honeypot-xxxxx                      1/1     Running   0          1m
ssh-honeypot-xxxxx                        1/1     Running   0          1m
```

### Step 7: Deploy Real Services (Protected)

```bash
# Deploy real e-commerce services in hidden namespace
kubectl apply -f k8s/deception-layer/real-services.yaml

# Verify real services are running
kubectl get pods -n ecommerce-internal
```

Expected output:
```
NAME                             READY   STATUS    RESTARTS   AGE
real-api-xxxxx                   1/1     Running   0          1m
real-database-xxxxx              1/1     Running   0          1m
real-frontend-xxxxx              1/1     Running   0          1m
```

### Step 8: Deploy Weave Scope (Visualization)

```bash
# Deploy Weave Scope
kubectl apply -f k8s/weave-scope/

# Wait for Weave Scope to be ready
kubectl wait --for=condition=Ready pods -l app.kubernetes.io/name=weave-scope -n weave --timeout=120s

# Verify Weave Scope is running
kubectl get pods -n weave
```

### Step 9: Start Port-Forward to Weave Scope

```bash
# Start port-forward (run in background)
kubectl port-forward svc/weave-scope 4040:80 -n weave &

# Verify it's accessible
curl -s http://localhost:4040/api | head -c 100

# Open in browser
echo "Open: http://localhost:4040"
```

### Step 10: Create Attacker Pod

```bash
# Create the attacker pod
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: attacker
  namespace: deception-system
  labels:
    app: attacker
    role: threat-actor
    scope.weave.works/role: attacker
    scope.weave.works/risk: malicious
    scope.weave.works/category: threat
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
        cpu: "100m"
        memory: "64Mi"
EOF

# Wait for attacker to be ready
kubectl wait --for=condition=Ready pod/attacker -n deception-system --timeout=60s
```

---

## Running the Demo

### Option 1: Use the Attack Script

```bash
./scripts/attack-all.sh
```

This script:
1. Creates the attacker pod (if not exists)
2. Attacks all 8 honeypots
3. Shows attack progress
4. Displays summary

### Option 2: Manual Attack Demonstration

```bash
# Attack Frontend Honeypot
kubectl exec -n deception-system attacker -- curl -s "http://frontend-honeypot:80/"
kubectl exec -n deception-system attacker -- curl -s "http://frontend-honeypot:80/login"
kubectl exec -n deception-system attacker -- curl -s "http://frontend-honeypot:80/search?q=admin"

# Attack API Honeypot
kubectl exec -n deception-system attacker -- curl -s "http://api-honeypot:8080/api/v1/users"
kubectl exec -n deception-system attacker -- curl -s "http://api-honeypot:8080/api/admin"

# Attack Admin Panel Honeypot
kubectl exec -n deception-system attacker -- curl -s "http://admin-honeypot:8081/admin"
kubectl exec -n deception-system attacker -- curl -s "http://admin-honeypot:8081/wp-admin"
kubectl exec -n deception-system attacker -- curl -s "http://admin-honeypot:8081/phpmyadmin"

# Attack MySQL Honeypot
kubectl exec -n deception-system attacker -- sh -c "nc -w 1 mysql-honeypot 3306 < /dev/null"

# Attack PostgreSQL Honeypot
kubectl exec -n deception-system attacker -- sh -c "nc -w 1 postgres-honeypot 5432 < /dev/null"

# Attack SSH Honeypot
kubectl exec -n deception-system attacker -- sh -c "echo 'SSH-2.0-Attacker' | nc -w 1 ssh-honeypot 22"

# Attack Redis Honeypot
kubectl exec -n deception-system attacker -- sh -c "echo 'INFO' | nc -w 1 redis-honeypot 6379"

# Attack Elasticsearch Honeypot
kubectl exec -n deception-system attacker -- curl -s "http://elasticsearch-honeypot:9200/_search"
```

### Option 3: SQL Injection / XSS Attacks

```bash
# SQL Injection on Frontend
kubectl exec -n deception-system attacker -- curl -s \
  "http://frontend-honeypot:80/search?q=1'+OR+'1'='1"

# SQL Injection on API
kubectl exec -n deception-system attacker -- curl -s \
  "http://api-honeypot:8080/api/users?id=1;DROP+TABLE+users--"

# Path Traversal
kubectl exec -n deception-system attacker -- curl -s \
  "http://admin-honeypot:8081/../../../../etc/passwd"

# XSS Attack
kubectl exec -n deception-system attacker -- curl -s \
  "http://frontend-honeypot:80/search?q=<script>alert(1)</script>"
```

---

## What Happens During Attack

### 1. Attacker Perspective
- Attacker scans network → finds 8 "services"
- Attacker attacks what looks like real infrastructure
- Attacker thinks they're making progress
- Attacker's tools and techniques are captured

### 2. Honeypot Response
Each honeypot logs detailed information:

**HTTP Honeypot Log Example:**
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

**SSH Honeypot Log Example:**
```json
{
  "event": "ssh_connection",
  "session_id": "def456",
  "source_ip": "10.244.0.33",
  "client_version": "SSH-2.0-Attacker"
}
```

**Database Honeypot Log Example:**
```json
{
  "event": "connection_opened",
  "session_id": "ghi789",
  "source_ip": "10.244.0.33",
  "protocol": "mysql"
}
```

### 3. Real Services
- Completely isolated in `ecommerce-internal` namespace
- Network policy blocks external access
- Attacker never sees or reaches them

---

## Viewing Results

### Weave Scope UI

**Access:** http://localhost:4040

**Navigation:**
1. Click **"Pods"** view (top menu)
2. You'll see all pods as nodes
3. Connection lines show network traffic

**What You'll See:**
```
                    ┌─────────────┐
                    │   Attacker  │
                    │     Pod     │
                    └──────┬──────┘
                           │
         ┌─────────────────┼─────────────────┐
         │        │        │        │        │
         ▼        ▼        ▼        ▼        ▼
    ┌────────┐┌────────┐┌────────┐┌────────┐┌────────┐
    │Frontend││  API   ││ Admin  ││ MySQL  ││Postgres│
    │Honeypot││Honeypot││Honeypot││Honeypot││Honeypot│
    └────────┘└────────┘└────────┘└────────┘└────────┘
         │        │        │
         ▼        ▼        ▼
    ┌────────┐┌────────┐┌────────┐
    │  SSH   ││ Redis  ││Elastic │
    │Honeypot││Honeypot││Honeypot│
    └────────┘└────────┘└────────┘

    (Real services have NO connections from attacker)
```

**Useful Filters:**
```
label:scope.weave.works/role:honeypot     # Show only honeypots
label:scope.weave.works/role:attacker     # Show only attacker
label:scope.weave.works/role:legitimate   # Show only real services
label:scope.weave.works/category:deception # Show deception layer
```

### Honeypot Logs

```bash
# View HTTP-based honeypot logs
kubectl logs -n deception-system deployment/frontend-honeypot --tail=20
kubectl logs -n deception-system deployment/api-honeypot --tail=20
kubectl logs -n deception-system deployment/admin-honeypot --tail=20
kubectl logs -n deception-system deployment/elasticsearch-honeypot --tail=20

# View database honeypot logs
kubectl logs -n deception-system deployment/mysql-honeypot --tail=20
kubectl logs -n deception-system deployment/postgres-honeypot --tail=20
kubectl logs -n deception-system deployment/redis-honeypot --tail=20

# View SSH honeypot logs
kubectl logs -n deception-system deployment/ssh-honeypot --tail=20

# Stream all honeypot logs in real-time
kubectl logs -n deception-system -l component=honeypot -f
```

### Check Topology via API

```bash
# Get topology data
curl -s http://localhost:4040/api/topology/pods | python3 -c "
import sys, json
data = json.load(sys.stdin)
nodes = data.get('nodes', {})
print(f'Total nodes: {len(nodes)}')
for nid, n in nodes.items():
    label = n.get('label', '')
    if 'honeypot' in label.lower() or 'attacker' in label.lower():
        print(f'  {label}')
"
```

---

## Troubleshooting

### Problem: Pods stuck in ImagePullBackOff or ErrImagePull

**Cause:** Docker images not built inside minikube's Docker environment.

**Solution:**
```bash
# Configure Docker to use minikube's daemon
eval $(minikube docker-env)

# Rebuild images
docker build -t deception-system/ssh-honeypot:latest ./honeypots/ssh/
docker build -t deception-system/http-honeypot:latest ./honeypots/http/
docker build -t deception-system/db-honeypot:latest ./honeypots/database/

# Restart deployments
kubectl rollout restart deployment -n deception-system
```

### Problem: Weave Scope not showing connections

**Cause:** Weave Scope updates topology every 60 seconds.

**Solution:**
```bash
# Generate more traffic
./scripts/attack-all.sh

# Wait 60 seconds
sleep 60

# Refresh browser or check API
curl -s http://localhost:4040/api/topology/pods | grep adjacency
```

### Problem: Port-forward keeps dying

**Solution:**
```bash
# Kill existing port-forwards
pkill -f "port-forward"

# Start with nohup
nohup kubectl port-forward svc/weave-scope 4040:80 -n weave > /dev/null 2>&1 &
```

### Problem: Attacker pod not creating (quota error)

**Solution:**
```bash
# Create with explicit resource limits
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
        cpu: "100m"
        memory: "64Mi"
EOF
```

### Problem: Cannot connect to honeypot services

**Solution:**
```bash
# Check services exist
kubectl get svc -n deception-system

# Check endpoints
kubectl get endpoints -n deception-system

# Test from inside cluster
kubectl exec -n deception-system attacker -- nslookup frontend-honeypot
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

### Remove Honeypots Only

```bash
kubectl delete -f k8s/deception-layer/honeypots-full.yaml
```

### Remove Everything (Full Cleanup)

```bash
# Delete all namespaces
kubectl delete namespace deception-system --ignore-not-found
kubectl delete namespace ecommerce-internal --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found
kubectl delete namespace weave --ignore-not-found

# Stop minikube
minikube stop

# Delete cluster completely (optional)
minikube delete
```

### Quick Reset (Keep Cluster)

```bash
# Delete and recreate
kubectl delete namespace deception-system --ignore-not-found
kubectl delete namespace ecommerce-internal --ignore-not-found
sleep 5

# Recreate namespace
kubectl create namespace deception-system

# Redeploy
kubectl apply -f k8s/deception-layer/honeypots-full.yaml
kubectl apply -f k8s/deception-layer/real-services.yaml
```

---

## Quick Reference

### Essential Commands

```bash
# Check all pods
kubectl get pods -n deception-system
kubectl get pods -n ecommerce-internal
kubectl get pods -n weave

# Check honeypots specifically
kubectl get pods -n deception-system -l component=honeypot

# View honeypot logs
kubectl logs -n deception-system deployment/frontend-honeypot --tail=20

# Run attack simulation
./scripts/attack-all.sh

# Access Weave Scope
kubectl port-forward svc/weave-scope 4040:80 -n weave &
# Open: http://localhost:4040

# Create attacker
kubectl apply -f - <<EOF
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
      limits:
        cpu: "100m"
        memory: "64Mi"
EOF

# Manual attack
kubectl exec -n deception-system attacker -- curl -s "http://frontend-honeypot:80/admin"
```

### File Locations

```
/home/dh33r4j/projects/dynamic-deception-system/
├── k8s/
│   ├── deception-layer/
│   │   ├── honeypots-full.yaml      # 8 honeypot deployments
│   │   └── real-services.yaml       # Real protected services
│   └── weave-scope/                 # Weave Scope configs
├── honeypots/
│   ├── ssh/                         # SSH honeypot code
│   ├── http/                        # HTTP honeypot code
│   └── database/                    # Database honeypot code
├── scripts/
│   ├── attack-all.sh                # Attack simulation script
│   ├── demo.sh                      # Interactive demo
│   └── setup-light.sh               # Setup script
├── COMPLETE-PROCEDURE.md            # This file
├── HOW-TO-DEMO.md                   # Demo guide
└── README.md                        # Project overview
```

### Weave Scope Filters

```
label:scope.weave.works/role:honeypot      # Honeypots only
label:scope.weave.works/role:attacker      # Attacker only
label:scope.weave.works/role:legitimate    # Real services only
label:scope.weave.works/category:deception # Deception layer
label:scope.weave.works/category:threat    # Threat actors
```

---

## Summary

This deception system demonstrates:

1. **8 Honeypots** that look like real services
2. **Attackers get trapped** in the deception layer
3. **All attacks are logged** for analysis
4. **Real services stay protected** and hidden
5. **Weave Scope visualizes** the attack in real-time

The key insight: Attackers waste time on fake services while their methods are captured, and real services remain untouched.
