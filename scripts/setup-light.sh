#!/bin/bash
# Setup script for Light Profile
# Target: 4GB RAM allocation
# Use case: Raspberry Pi, small VMs, testing

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  Deception System - Light Profile Setup"
echo "  Target: 4GB RAM allocation"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi

    log_info "Prerequisites check passed."
}

# Check available resources
check_resources() {
    log_info "Checking available resources..."

    # Get node memory
    TOTAL_MEM=$(kubectl get nodes -o jsonpath='{.items[0].status.capacity.memory}')
    log_info "Total node memory: $TOTAL_MEM"

    log_warn "Light profile is designed for systems with ~4GB RAM"
    log_warn "Some features are disabled to save resources"
}

# Create namespaces
create_namespaces() {
    log_info "Creating namespaces..."

    kubectl apply -f "$PROJECT_DIR/configs/light/namespace.yaml"
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

    log_info "Namespaces created."
}

# Deploy honeypots
deploy_honeypots() {
    log_info "Deploying honeypots (light configuration)..."

    kubectl apply -f "$PROJECT_DIR/configs/light/honeypots.yaml"

    log_info "Honeypots deployed."
}

# Deploy operator
deploy_operator() {
    log_info "Deploying deception operator..."

    # Create operator deployment with light profile
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deception-operator
  namespace: deception-system
spec:
  replicas: 1
  selector:
    matchLabels:
      app: deception-operator
  template:
    metadata:
      labels:
        app: deception-operator
    spec:
      containers:
      - name: operator
        image: deception-system/operator:latest
        args:
          - '--profile=light'
          - '--metrics-bind-address=:8080'
        resources:
          requests:
            memory: "32Mi"
            cpu: "25m"
          limits:
            memory: "64Mi"
            cpu: "100m"
        ports:
        - containerPort: 8080
          name: metrics
EOF

    log_info "Operator deployed."
}

# Deploy monitoring (minimal)
deploy_monitoring() {
    log_info "Deploying monitoring stack (minimal)..."

    # Prometheus with reduced retention
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: prometheus-config
  namespace: monitoring
data:
  prometheus.yaml: |
    global:
      scrape_interval: 60s
      evaluation_interval: 60s
    scrape_configs:
      - job_name: 'prometheus'
        static_configs:
          - targets: ['localhost:9090']
      - job_name: 'honeypots'
        kubernetes_sd_configs:
          - role: pod
            namespaces:
              names: [deception-system]
        relabel_configs:
          - source_labels: [__meta_kubernetes_pod_label_component]
            action: keep
            regex: honeypot
EOF

    # Deploy minimal Prometheus
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: prometheus
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: prometheus
  template:
    metadata:
      labels:
        app: prometheus
    spec:
      containers:
      - name: prometheus
        image: prom/prometheus:v2.48.0
        args:
          - '--config.file=/etc/prometheus/prometheus.yaml'
          - '--storage.tsdb.retention.time=6h'
          - '--storage.tsdb.retention.size=500MB'
        resources:
          requests:
            memory: "128Mi"
            cpu: "50m"
          limits:
            memory: "256Mi"
            cpu: "200m"
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-config
EOF

    log_info "Monitoring deployed (minimal configuration)."
    log_warn "Grafana and Loki are disabled in light profile."
}

# Skip Weave Scope in light profile
skip_weave_scope() {
    log_warn "Weave Scope is disabled in light profile to save resources."
    log_info "Use 'kubectl top pods' for basic monitoring."
}

# Show summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "  Light Profile Setup Complete!"
    echo "=========================================="
    echo ""
    log_info "Deployed components:"
    echo "  - SSH Honeypot (64MB limit)"
    echo "  - HTTP Honeypot (64MB limit)"
    echo "  - DB Honeypot (64MB limit)"
    echo "  - Operator (64MB limit)"
    echo "  - Prometheus (256MB limit)"
    echo ""
    log_warn "Disabled components (to save resources):"
    echo "  - SMTP Honeypot"
    echo "  - Grafana"
    echo "  - Loki"
    echo "  - Weave Scope"
    echo "  - E-commerce demo"
    echo ""
    echo "Total memory budget: ~1GB"
    echo ""
    log_info "To check deployment status:"
    echo "  kubectl get pods -n deception-system"
    echo "  kubectl get pods -n monitoring"
}

# Main
main() {
    check_prerequisites
    check_resources
    create_namespaces
    deploy_honeypots
    deploy_operator
    deploy_monitoring
    skip_weave_scope
    show_summary
}

main "$@"
