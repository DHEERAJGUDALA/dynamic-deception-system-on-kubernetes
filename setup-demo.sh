#!/bin/bash
# Configuration
REPO_URL="https://github.com/DHEERAJGUDALA/dynamic-deception-system-on-kubernetes.git"
NAMESPACE="deception-zone"
REPO_DIR="dynamic-deception-system-on-kubernetes"

echo "🛡️ Initializing Dynamic Deception Environment..."

# 1. Cleanup & Fresh Clone
rm -rf "$REPO_DIR"
git clone "$REPO_URL"
cd "$REPO_DIR" || exit

# 2. Setup Namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 3. Apply Resource Quotas (i3 Optimization)
echo "⚙️ Applying Medium-tier Resource Configs..."
kubectl apply -f configs/medium/ -n $NAMESPACE

# 4. Deploy Core Components (Order Matters!)
echo "🚀 Deploying Target E-commerce App..."
kubectl apply -f ecommerce/ -n $NAMESPACE

echo "🕵️ Deploying Go Operator (The Brain)..."
kubectl apply -f operator/ -n $NAMESPACE

echo "🕸️ Deploying Initial Honeypots (SSH/HTTP)..."
kubectl apply -f honeypots/ssh/ -n $NAMESPACE
kubectl apply -f honeypots/http/ -n $NAMESPACE

# 5. Setup Visualization
echo "📊 Launching Weave Scope..."
kubectl apply -f weave-scope/ -n $NAMESPACE

echo "✅ Deployment Triggered. Checking status..."
kubectl get pods -n $NAMESPACE
