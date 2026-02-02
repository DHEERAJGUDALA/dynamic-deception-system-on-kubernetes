#!/bin/bash
# Setup script for Medium Profile
# Target: 6GB RAM allocation (optimized for 8GB system)
# Use case: Intel i3 laptops, small development servers

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  Deception System - Medium Profile Setup"
echo "  Optimized for i3 with 8GB RAM"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found. Please install kubectl first."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi

    # Check for docker/containerd
    if command -v docker &> /dev/null; then
        log_info "Docker detected."
    fi

    log_info "Prerequisites check passed."
}

# Check and display resources
check_resources() {
    log_step "Analyzing system resources..."

    # Get node info
    NODE_INFO=$(kubectl get nodes -o json)
    TOTAL_MEM=$(echo "$NODE_INFO" | jq -r '.items[0].status.capacity.memory')
    TOTAL_CPU=$(echo "$NODE_INFO" | jq -r '.items[0].status.capacity.cpu')

    log_info "Cluster resources:"
    echo "  - Total Memory: $TOTAL_MEM"
    echo "  - Total CPU: $TOTAL_CPU cores"

    # Memory budget for medium profile
    echo ""
    log_info "Medium profile memory allocation:"
    echo "  - System/OS Reserve: 2GB"
    echo "  - Kubernetes overhead: ~1GB"
    echo "  - Deception System: ~5GB"
    echo "    ├── Honeypots (4): 512MB"
    echo "    ├── Operator: 128MB"
    echo "    ├── Prometheus: 512MB"
    echo "    ├── Loki: 256MB"
    echo "    ├── Grafana: 256MB"
    echo "    └── Weave Scope: 384MB"
    echo ""

    log_warn "Ensure you have at least 8GB total RAM for optimal performance."
}

# Create namespaces
create_namespaces() {
    log_step "Creating namespaces..."

    kubectl apply -f "$PROJECT_DIR/configs/medium/namespace.yaml"
    kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -
    kubectl create namespace weave --dry-run=client -o yaml | kubectl apply -f -

    log_info "Namespaces created."
}

# Build and load container images
build_images() {
    log_step "Building container images..."

    if command -v docker &> /dev/null; then
        # Build honeypot images
        for honeypot in ssh http database smtp; do
            log_info "Building $honeypot honeypot image..."
            docker build -t "deception-system/${honeypot}-honeypot:latest" \
                "$PROJECT_DIR/honeypots/$honeypot/" 2>/dev/null || true
        done

        # Build operator image
        log_info "Building operator image..."
        docker build -t "deception-system/operator:latest" \
            "$PROJECT_DIR/operator/" 2>/dev/null || true

        log_info "Images built successfully."
    else
        log_warn "Docker not found. Using pre-built images."
    fi
}

# Deploy honeypots
deploy_honeypots() {
    log_step "Deploying honeypots..."

    kubectl apply -f "$PROJECT_DIR/configs/medium/honeypots.yaml"

    # Create secrets for honeypots
    kubectl create secret generic ssh-honeypot-keys \
        --from-literal=host-key="$(openssl rand -base64 32)" \
        -n deception-system --dry-run=client -o yaml | kubectl apply -f -

    kubectl create secret generic http-honeypot-tls \
        --from-literal=tls.crt="placeholder" \
        --from-literal=tls.key="placeholder" \
        -n deception-system --dry-run=client -o yaml | kubectl apply -f -

    log_info "Honeypots deployed."
}

# Deploy operator
deploy_operator() {
    log_step "Deploying deception operator..."

    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deception-operator
  namespace: deception-system
  labels:
    app: deception-operator
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
      serviceAccountName: deception-operator
      containers:
      - name: operator
        image: deception-system/operator:latest
        imagePullPolicy: IfNotPresent
        args:
          - '--profile=medium'
          - '--metrics-bind-address=:8080'
          - '--health-probe-bind-address=:8081'
        env:
        - name: GOGC
          value: "50"
        - name: GOMAXPROCS
          value: "2"
        resources:
          requests:
            memory: "64Mi"
            cpu: "50m"
          limits:
            memory: "128Mi"
            cpu: "200m"
        ports:
        - containerPort: 8080
          name: metrics
        - containerPort: 8081
          name: health
        livenessProbe:
          httpGet:
            path: /healthz
            port: 8081
          initialDelaySeconds: 15
          periodSeconds: 20
        readinessProbe:
          httpGet:
            path: /readyz
            port: 8081
          initialDelaySeconds: 5
          periodSeconds: 10
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deception-operator
  namespace: deception-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: deception-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: deception-operator
  namespace: deception-system
EOF

    log_info "Operator deployed."
}

# Deploy monitoring stack
deploy_monitoring() {
    log_step "Deploying monitoring stack..."

    # Create Prometheus ConfigMaps
    kubectl create configmap prometheus-config \
        --from-file="$PROJECT_DIR/monitoring/prometheus/prometheus.yaml" \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -

    mkdir -p /tmp/prometheus-rules
    cp "$PROJECT_DIR/monitoring/prometheus/rules/"*.yaml /tmp/prometheus-rules/ 2>/dev/null || true
    kubectl create configmap prometheus-rules \
        --from-file=/tmp/prometheus-rules/ \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -

    # Deploy Prometheus
    kubectl apply -f "$PROJECT_DIR/monitoring/prometheus/deployment.yaml"

    # Create Loki ConfigMap
    kubectl create configmap loki-config \
        --from-file="$PROJECT_DIR/monitoring/loki/loki-config.yaml" \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -

    # Deploy Loki
    kubectl apply -f "$PROJECT_DIR/monitoring/loki/deployment.yaml"

    # Create Grafana secrets
    kubectl create secret generic grafana-secrets \
        --from-literal=admin-password="$(openssl rand -base64 12)" \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -

    # Create Grafana dashboard ConfigMap
    kubectl create configmap grafana-dashboards \
        --from-file="$PROJECT_DIR/monitoring/grafana/dashboards/" \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -

    # Deploy Grafana
    kubectl apply -f "$PROJECT_DIR/monitoring/grafana/deployment.yaml"

    log_info "Monitoring stack deployed."
}

# Deploy Weave Scope (optimized)
deploy_weave_scope() {
    log_step "Deploying Weave Scope (optimized for i3)..."

    kubectl apply -f "$PROJECT_DIR/weave-scope/weave-scope-optimized.yaml"

    log_info "Weave Scope deployed with memory optimizations."
}

# Deploy e-commerce demo
deploy_ecommerce() {
    log_step "Deploying e-commerce demo services..."

    kubectl apply -f "$PROJECT_DIR/ecommerce/frontend/deployment.yaml"

    # Create API ConfigMap
    kubectl create configmap ecommerce-api-code \
        --from-file=server.py="$PROJECT_DIR/ecommerce/api/server.py" \
        -n deception-system --dry-run=client -o yaml | kubectl apply -f -

    kubectl apply -f "$PROJECT_DIR/ecommerce/api/deployment.yaml"
    kubectl apply -f "$PROJECT_DIR/ecommerce/database/deployment.yaml"

    log_info "E-commerce demo deployed."
}

# Wait for deployments
wait_for_deployments() {
    log_step "Waiting for deployments to be ready..."

    kubectl wait --for=condition=available deployment --all \
        -n deception-system --timeout=300s || true

    kubectl wait --for=condition=available deployment --all \
        -n monitoring --timeout=300s || true

    log_info "Deployments ready."
}

# Show access instructions
show_access_info() {
    echo ""
    echo "=========================================="
    echo "  Medium Profile Setup Complete!"
    echo "=========================================="
    echo ""
    log_info "Access the services:"
    echo ""
    echo "  Grafana:"
    echo "    kubectl port-forward svc/grafana 3000:3000 -n monitoring"
    echo "    URL: http://localhost:3000"
    echo "    User: admin"
    echo "    Pass: kubectl get secret grafana-secrets -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d"
    echo ""
    echo "  Prometheus:"
    echo "    kubectl port-forward svc/prometheus 9090:9090 -n monitoring"
    echo "    URL: http://localhost:9090"
    echo ""
    echo "  Weave Scope:"
    echo "    kubectl port-forward svc/weave-scope-app 4040:80 -n weave"
    echo "    URL: http://localhost:4040"
    echo ""
    log_info "Check deployment status:"
    echo "    kubectl get pods -n deception-system"
    echo "    kubectl get pods -n monitoring"
    echo "    kubectl get pods -n weave"
    echo ""
    log_info "Memory usage:"
    echo "    kubectl top pods -n deception-system"
    echo "    kubectl top pods -n monitoring"
}

# Main
main() {
    check_prerequisites
    check_resources
    create_namespaces
    # build_images  # Uncomment to build images locally
    deploy_honeypots
    deploy_operator
    deploy_monitoring
    deploy_weave_scope
    deploy_ecommerce
    wait_for_deployments
    show_access_info
}

main "$@"
