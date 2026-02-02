#!/bin/bash
# Status check script

echo "=========================================="
echo "  Deception System Status"
echo "=========================================="

echo ""
echo "=== NAMESPACES ==="
kubectl get namespaces | grep -E "deception-system|monitoring|weave" || echo "No deception namespaces found"

echo ""
echo "=== DECEPTION SYSTEM PODS ==="
kubectl get pods -n deception-system 2>/dev/null || echo "Namespace not found"

echo ""
echo "=== MONITORING PODS ==="
kubectl get pods -n monitoring 2>/dev/null || echo "Namespace not found"

echo ""
echo "=== WEAVE SCOPE PODS ==="
kubectl get pods -n weave 2>/dev/null || echo "Namespace not found"

echo ""
echo "=== RESOURCE USAGE ==="
kubectl top pods -n deception-system 2>/dev/null || echo "Metrics not available"

echo ""
echo "=== SERVICES ==="
kubectl get svc -n deception-system 2>/dev/null
kubectl get svc -n monitoring 2>/dev/null
