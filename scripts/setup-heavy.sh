#!/bin/bash
# Setup script for Heavy Profile
# Target: 8GB+ RAM allocation
# Use case: Production servers, dedicated deception infrastructure

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

echo "=========================================="
echo "  Deception System - Heavy Profile Setup"
echo "  Production-grade configuration"
echo "=========================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }
log_step() { echo -e "${BLUE}[STEP]${NC} $1"; }
log_prod() { echo -e "${MAGENTA}[PROD]${NC} $1"; }

# Check prerequisites
check_prerequisites() {
    log_step "Checking prerequisites..."

    if ! command -v kubectl &> /dev/null; then
        log_error "kubectl not found."
        exit 1
    fi

    if ! kubectl cluster-info &> /dev/null; then
        log_error "Cannot connect to Kubernetes cluster."
        exit 1
    fi

    # Check for helm (optional but recommended)
    if command -v helm &> /dev/null; then
        log_info "Helm detected - can use for advanced deployments."
    fi

    log_info "Prerequisites check passed."
}

# Check resources
check_resources() {
    log_step "Analyzing cluster resources..."

    NODE_COUNT=$(kubectl get nodes --no-headers | wc -l)
    TOTAL_MEM=$(kubectl get nodes -o jsonpath='{.items[*].status.capacity.memory}' | tr ' ' '\n' | head -1)
    TOTAL_CPU=$(kubectl get nodes -o jsonpath='{.items[*].status.capacity.cpu}' | tr ' ' '\n' | head -1)

    log_info "Cluster overview:"
    echo "  - Nodes: $NODE_COUNT"
    echo "  - Memory per node: $TOTAL_MEM"
    echo "  - CPU per node: $TOTAL_CPU cores"
    echo ""

    log_prod "Heavy profile resource allocation:"
    echo "  - Honeypots (4 types, 2 replicas each): 2GB"
    echo "  - Operator (2 replicas): 512MB"
    echo "  - Prometheus: 1GB"
    echo "  - Loki: 512MB"
    echo "  - Grafana: 512MB"
    echo "  - Alertmanager: 128MB"
    echo "  - Weave Scope: 512MB"
    echo "  - E-commerce Demo: 768MB"
    echo "  ────────────────────────"
    echo "  Total: ~6GB (with headroom)"
    echo ""

    if [[ "$NODE_COUNT" -lt 2 ]]; then
        log_warn "Single node detected. For production, consider multi-node cluster."
    fi
}

# Create namespaces with production settings
create_namespaces() {
    log_step "Creating namespaces with production settings..."

    kubectl apply -f "$PROJECT_DIR/configs/heavy/namespace.yaml"

    for ns in monitoring weave; do
        kubectl create namespace $ns --dry-run=client -o yaml | kubectl apply -f -
    done

    # Add network policies
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: deception-system
spec:
  podSelector: {}
  policyTypes:
  - Ingress
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-honeypot-ingress
  namespace: deception-system
spec:
  podSelector:
    matchLabels:
      component: honeypot
  policyTypes:
  - Ingress
  ingress:
  - ports:
    - port: 2222
    - port: 8080
    - port: 3306
    - port: 2525
    - port: 9100
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-monitoring
  namespace: deception-system
spec:
  podSelector: {}
  policyTypes:
  - Ingress
  ingress:
  - from:
    - namespaceSelector:
        matchLabels:
          name: monitoring
    ports:
    - port: 9100
EOF

    log_info "Namespaces and network policies created."
}

# Deploy honeypots with HA
deploy_honeypots() {
    log_step "Deploying honeypots (HA configuration)..."

    kubectl apply -f "$PROJECT_DIR/configs/heavy/honeypots.yaml"

    # Create production secrets
    kubectl create secret generic ssh-honeypot-keys \
        --from-literal=host-key="$(openssl rand -base64 64)" \
        -n deception-system --dry-run=client -o yaml | kubectl apply -f -

    # Generate self-signed TLS cert for HTTP honeypot
    openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
        -keyout /tmp/tls.key -out /tmp/tls.crt \
        -subj "/CN=honeypot.local" 2>/dev/null

    kubectl create secret tls http-honeypot-tls \
        --cert=/tmp/tls.crt --key=/tmp/tls.key \
        -n deception-system --dry-run=client -o yaml | kubectl apply -f -

    rm -f /tmp/tls.key /tmp/tls.crt

    # Create fake services config for HTTP honeypot
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: http-honeypot-services
  namespace: deception-system
data:
  services.json: |
    {
      "services": [
        {"path": "/admin", "type": "wordpress"},
        {"path": "/phpmyadmin", "type": "phpmyadmin"},
        {"path": "/api", "type": "rest-api"},
        {"path": "/jenkins", "type": "jenkins"},
        {"path": "/grafana", "type": "grafana"}
      ]
    }
EOF

    log_info "Honeypots deployed with HA configuration."
}

# Deploy operator with leader election
deploy_operator() {
    log_step "Deploying operator (HA with leader election)..."

    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: deception-operator
  namespace: deception-system
spec:
  replicas: 2
  selector:
    matchLabels:
      app: deception-operator
  template:
    metadata:
      labels:
        app: deception-operator
    spec:
      serviceAccountName: deception-operator
      affinity:
        podAntiAffinity:
          preferredDuringSchedulingIgnoredDuringExecution:
          - weight: 100
            podAffinityTerm:
              labelSelector:
                matchLabels:
                  app: deception-operator
              topologyKey: kubernetes.io/hostname
      containers:
      - name: operator
        image: deception-system/operator:latest
        args:
          - '--profile=heavy'
          - '--leader-elect=true'
          - '--metrics-bind-address=:8080'
        env:
        - name: GOGC
          value: "100"
        - name: GOMAXPROCS
          value: "4"
        resources:
          requests:
            memory: "128Mi"
            cpu: "100m"
          limits:
            memory: "256Mi"
            cpu: "500m"
        ports:
        - containerPort: 8080
          name: metrics
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: deception-operator
  namespace: deception-system
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: deception-operator
rules:
- apiGroups: [""]
  resources: ["pods", "services", "secrets", "configmaps"]
  verbs: ["*"]
- apiGroups: ["apps"]
  resources: ["deployments", "daemonsets"]
  verbs: ["*"]
- apiGroups: ["coordination.k8s.io"]
  resources: ["leases"]
  verbs: ["*"]
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: deception-operator
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: deception-operator
subjects:
- kind: ServiceAccount
  name: deception-operator
  namespace: deception-system
EOF

    log_info "Operator deployed with leader election."
}

# Deploy full monitoring stack
deploy_monitoring() {
    log_step "Deploying production monitoring stack..."

    # Prometheus with persistent storage
    kubectl create configmap prometheus-config \
        --from-file="$PROJECT_DIR/monitoring/prometheus/prometheus.yaml" \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -

    mkdir -p /tmp/prometheus-rules
    cp "$PROJECT_DIR/monitoring/prometheus/rules/"*.yaml /tmp/prometheus-rules/ 2>/dev/null || true
    kubectl create configmap prometheus-rules \
        --from-file=/tmp/prometheus-rules/ \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -

    # Deploy Prometheus with production settings
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
      serviceAccountName: prometheus
      containers:
      - name: prometheus
        image: prom/prometheus:v2.48.0
        args:
          - '--config.file=/etc/prometheus/prometheus.yaml'
          - '--storage.tsdb.path=/prometheus'
          - '--storage.tsdb.retention.time=7d'
          - '--web.enable-lifecycle'
          - '--query.max-samples=200000'
        resources:
          requests:
            memory: "512Mi"
            cpu: "200m"
          limits:
            memory: "1Gi"
            cpu: "1000m"
        ports:
        - containerPort: 9090
        volumeMounts:
        - name: config
          mountPath: /etc/prometheus
        - name: rules
          mountPath: /etc/prometheus/rules
        - name: storage
          mountPath: /prometheus
      volumes:
      - name: config
        configMap:
          name: prometheus-config
      - name: rules
        configMap:
          name: prometheus-rules
      - name: storage
        emptyDir:
          sizeLimit: 20Gi
---
apiVersion: v1
kind: Service
metadata:
  name: prometheus
  namespace: monitoring
spec:
  selector:
    app: prometheus
  ports:
  - port: 9090
    targetPort: 9090
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: prometheus
  namespace: monitoring
---
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: prometheus
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: prometheus
  namespace: monitoring
EOF

    # Deploy Alertmanager
    cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  replicas: 1
  selector:
    matchLabels:
      app: alertmanager
  template:
    metadata:
      labels:
        app: alertmanager
    spec:
      containers:
      - name: alertmanager
        image: prom/alertmanager:v0.26.0
        resources:
          requests:
            memory: "64Mi"
            cpu: "25m"
          limits:
            memory: "128Mi"
            cpu: "100m"
        ports:
        - containerPort: 9093
---
apiVersion: v1
kind: Service
metadata:
  name: alertmanager
  namespace: monitoring
spec:
  selector:
    app: alertmanager
  ports:
  - port: 9093
    targetPort: 9093
EOF

    # Deploy Loki
    kubectl create configmap loki-config \
        --from-file="$PROJECT_DIR/monitoring/loki/loki-config.yaml" \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -
    kubectl apply -f "$PROJECT_DIR/monitoring/loki/deployment.yaml"

    # Deploy Grafana
    kubectl create secret generic grafana-secrets \
        --from-literal=admin-password="$(openssl rand -base64 16)" \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -

    kubectl create configmap grafana-dashboards \
        --from-file="$PROJECT_DIR/monitoring/grafana/dashboards/" \
        -n monitoring --dry-run=client -o yaml | kubectl apply -f -

    kubectl apply -f "$PROJECT_DIR/monitoring/grafana/deployment.yaml"

    log_info "Production monitoring stack deployed."
}

# Deploy Weave Scope (full features)
deploy_weave_scope() {
    log_step "Deploying Weave Scope (full features)..."

    kubectl apply -f "$PROJECT_DIR/weave-scope/weave-scope-optimized.yaml"

    log_info "Weave Scope deployed."
}

# Deploy e-commerce with HA
deploy_ecommerce() {
    log_step "Deploying e-commerce demo (HA)..."

    kubectl apply -f "$PROJECT_DIR/ecommerce/frontend/deployment.yaml"

    kubectl create configmap ecommerce-api-code \
        --from-file=server.py="$PROJECT_DIR/ecommerce/api/server.py" \
        -n deception-system --dry-run=client -o yaml | kubectl apply -f -

    kubectl apply -f "$PROJECT_DIR/ecommerce/api/deployment.yaml"
    kubectl apply -f "$PROJECT_DIR/ecommerce/database/deployment.yaml"

    log_info "E-commerce demo deployed."
}

# Wait and verify
wait_and_verify() {
    log_step "Waiting for all deployments..."

    kubectl wait --for=condition=available deployment --all \
        -n deception-system --timeout=300s || true
    kubectl wait --for=condition=available deployment --all \
        -n monitoring --timeout=300s || true
    kubectl wait --for=condition=available deployment --all \
        -n weave --timeout=300s || true

    echo ""
    log_prod "Deployment verification:"
    echo ""
    echo "Deception System namespace:"
    kubectl get pods -n deception-system -o wide
    echo ""
    echo "Monitoring namespace:"
    kubectl get pods -n monitoring -o wide
    echo ""
    echo "Weave namespace:"
    kubectl get pods -n weave -o wide
}

# Show production summary
show_summary() {
    echo ""
    echo "=========================================="
    echo "  Heavy Profile Setup Complete!"
    echo "  Production-Ready Deployment"
    echo "=========================================="
    echo ""
    log_prod "Deployed Components:"
    echo ""
    echo "  HONEYPOTS (HA - 2 replicas each):"
    echo "    ├── SSH Honeypot     (256MB limit)"
    echo "    ├── HTTP Honeypot    (256MB limit)"
    echo "    ├── Database Honeypot(256MB limit)"
    echo "    └── SMTP Honeypot    (256MB limit)"
    echo ""
    echo "  OPERATOR:"
    echo "    └── 2 replicas with leader election"
    echo ""
    echo "  MONITORING:"
    echo "    ├── Prometheus  (1GB limit, 7d retention)"
    echo "    ├── Alertmanager"
    echo "    ├── Loki        (512MB limit)"
    echo "    └── Grafana     (512MB limit)"
    echo ""
    echo "  VISUALIZATION:"
    echo "    └── Weave Scope (full features)"
    echo ""
    log_info "Access URLs (after port-forwarding):"
    echo "    Grafana:     http://localhost:3000"
    echo "    Prometheus:  http://localhost:9090"
    echo "    Alertmanager: http://localhost:9093"
    echo "    Weave Scope: http://localhost:4040"
    echo ""
    log_info "Get Grafana password:"
    echo "    kubectl get secret grafana-secrets -n monitoring -o jsonpath='{.data.admin-password}' | base64 -d"
    echo ""
    log_warn "Production recommendations:"
    echo "    - Configure external alerting (Slack, PagerDuty)"
    echo "    - Enable persistent storage for Prometheus/Loki"
    echo "    - Set up ingress with TLS for external access"
    echo "    - Configure backup for alert rules and dashboards"
}

# Main
main() {
    check_prerequisites
    check_resources
    create_namespaces
    deploy_honeypots
    deploy_operator
    deploy_monitoring
    deploy_weave_scope
    deploy_ecommerce
    wait_and_verify
    show_summary
}

main "$@"
