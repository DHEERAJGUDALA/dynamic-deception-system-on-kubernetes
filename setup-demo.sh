#!/bin/bash

# 1. Define your project details
REPO_URL="https://github.com/DHEERAJGUDALA/dynamic-deception-system-on-kubernetes"
NAMESPACE="deception-zone"

echo "🚀 Starting Dynamic Deception System Setup..."

# 2. Clone the latest code
git clone $REPO_URL project
cd project

# 3. Create the isolated namespace
kubectl create namespace $NAMESPACE

# 4. Deploy your Spring Boot Deception Controller
echo "📦 Deploying Deception Controller..."
kubectl apply -f k8s/controller-deployment.yaml -n $NAMESPACE

# 5. Deploy the initial Decoy (Honeypot)
echo "🕸️ Setting up the first Decoy trap..."
kubectl apply -f k8s/honeypot-service.yaml -n $NAMESPACE

# 6. Wait for pods to be ready
echo "⏳ Waiting for pods to initialize..."
kubectl wait --for=condition=ready pod -l app=deception-system -n $NAMESPACE --timeout=60s

echo "✅ SYSTEM LIVE. Ready for attack simulation."
