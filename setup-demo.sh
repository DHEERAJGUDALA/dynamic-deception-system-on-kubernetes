#!/bin/bash

# 1. Configuration
REPO_URL="https://github.com/DHEERAJGUDALA/dynamic-deception-system-on-kubernetes.git"
NAMESPACE="deception-zone"
REPO_DIR="dynamic-deception-system-on-kubernetes"

echo "🚀 Starting Idempotent Setup..."

# 2. Handle the Directory (Cleanup old clones)
if [ -d "$REPO_DIR" ]; then
    echo "🧹 Cleaning up old project folder..."
    rm -rf "$REPO_DIR"
fi

# 3. Clone and Enter
git clone "$REPO_URL"
cd "$REPO_DIR" || { echo "❌ Failed to enter directory"; exit 1; }

# 4. Handle Namespace (Ignore error if exists)
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 5. Deploy with checks
# NOTE: Make sure your folder is named 'k8s' and NOT 'K8s' or 'kubernetes'
if [ -d "k8s" ]; then
    echo "📦 Deploying manifests from k8s/ folder..."
    kubectl apply -f k8s/ -n $NAMESPACE
else
    echo "⚠️ Error: 'k8s' folder not found! Checking current directory..."
    ls -R
    exit 1
fi

# 6. Wait for the Dynamic Controller (Your Spring Boot app)
echo "⏳ Waiting for Deception Controller to be ready..."
kubectl wait --for=condition=available deployment/deception-controller -n $NAMESPACE --timeout=60s

echo "✅ SYSTEM LIVE. You are ready to present!"
