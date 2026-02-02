#!/bin/bash
# Cleanup script - removes all deception system components

set -e

echo "Cleaning up Deception System..."

# Delete namespaces (this removes all resources in them)
kubectl delete namespace deception-system --ignore-not-found
kubectl delete namespace monitoring --ignore-not-found
kubectl delete namespace weave --ignore-not-found

# Delete cluster-wide resources
kubectl delete clusterrole deception-operator prometheus weave-scope --ignore-not-found
kubectl delete clusterrolebinding deception-operator prometheus weave-scope --ignore-not-found
kubectl delete priorityclass low-priority medium-priority high-priority --ignore-not-found

echo "Cleanup complete."
