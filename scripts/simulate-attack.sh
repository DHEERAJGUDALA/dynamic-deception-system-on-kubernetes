#!/bin/bash
NAMESPACE="deception-zone"

echo "👤 Attacker identifies target service..."
TARGET_IP=$(kubectl get svc -n $NAMESPACE | grep ecommerce | awk '{print $3}')

echo "🧨 Launching brute-force simulation against $TARGET_IP..."
# This simulates unauthorized access attempts in the logs
kubectl run attacker-pod --image=radial/busyboxplus:curl -n $NAMESPACE -- \
  sh -c "while true; do curl -s $TARGET_IP/admin/login; sleep 1; done"

echo "🔍 Monitoring Controller response..."
sleep 5
echo "⚠️ Intrusion Detected! Controller is deploying a dynamic decoy..."

# Show the new pod appearing
watch -n 1 "kubectl get pods -n $NAMESPACE -l app=decoy"
