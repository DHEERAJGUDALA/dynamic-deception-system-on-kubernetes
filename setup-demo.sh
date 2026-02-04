#!/bin/bash

# Configuration
REPO_URL="https://github.com/DHEERAJGUDALA/dynamic-deception-system-on-kubernetes.git"
REPO_NAME="dynamic-deception-system-on-kubernetes"
NAMESPACE="deception-zone"

echo "🛡️ Initializing Dynamic Deception System..."

# 1. Cleanup and Clone
rm -rf "$REPO_NAME"
git clone "$REPO_URL"
cd "$REPO_NAME" || { echo "❌ Failed to find project folder"; exit 1; }

# 2. Create Namespace
kubectl create namespace $NAMESPACE --dry-run=client -o yaml | kubectl apply -f -

# 3. Apply Kubernetes Manifests from your /k8s folder
# This uses the specific folder from your GitHub link
if [ -d "k8s" ]; then
    echo "📦 Deploying all manifests from the k8s directory..."
    kubectl apply -f k8s/ -n $NAMESPACE
else
    echo "❌ Error: k8s folder not found in $(pwd)"
    ls -F
    exit 1
fi

echo "⏳ Waiting for the environment to stabilize..."
sleep 10
kubectl get pods -n $NAMESPACE

echo "✅ Deployment complete. System is watching for intruders."
