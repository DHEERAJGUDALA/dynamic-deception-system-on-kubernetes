#!/bin/bash
# Apply Weave Scope labels to all deployments for visual topology
# Uses valid K8s label values with emoji annotations for display

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_step() { echo -e "${BLUE}[→]${NC} $1"; }

echo "╔══════════════════════════════════════════════════════════════╗"
echo "║     Weave Scope Label Injector for Deception Topology        ║"
echo "╚══════════════════════════════════════════════════════════════╝"
echo ""

# Function to patch deployment with labels
patch_deployment() {
    local name=$1
    local namespace=$2
    local role=$3
    local type=$4
    local risk=$5
    local category=$6
    local display_role=$7

    # Check if deployment exists
    if ! kubectl get deployment "$name" -n "$namespace" &>/dev/null; then
        log_warn "Deployment $name not found in $namespace - skipping"
        return 0
    fi

    log_step "Patching $name in $namespace..."

    kubectl patch deployment "$name" -n "$namespace" --type='merge' -p "{
        \"spec\": {
            \"template\": {
                \"metadata\": {
                    \"labels\": {
                        \"scope.weave.works/role\": \"$role\",
                        \"scope.weave.works/type\": \"$type\",
                        \"scope.weave.works/risk\": \"$risk\",
                        \"scope.weave.works/category\": \"$category\"
                    },
                    \"annotations\": {
                        \"scope.weave.works/display-role\": \"$display_role\"
                    }
                }
            }
        }
    }" 2>/dev/null && log_info "Patched $name" || log_warn "Failed to patch $name"
}

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│  🍯 Labeling HONEYPOTS (Decoy Systems)                       │"
echo "└──────────────────────────────────────────────────────────────┘"

patch_deployment "ssh-honeypot" "deception-system" \
    "honeypot" "ssh" "decoy" "deception" "🍯 SSH Honeypot"

patch_deployment "http-honeypot" "deception-system" \
    "honeypot" "http" "decoy" "deception" "🍯 HTTP Honeypot"

patch_deployment "db-honeypot" "deception-system" \
    "honeypot" "mysql" "decoy" "deception" "🍯 MySQL Honeypot"

patch_deployment "smtp-honeypot" "deception-system" \
    "honeypot" "smtp" "decoy" "deception" "🍯 SMTP Honeypot"

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│  ⚙️  Labeling OPERATOR (Controller)                          │"
echo "└──────────────────────────────────────────────────────────────┘"

patch_deployment "deception-operator" "deception-system" \
    "controller" "operator" "infrastructure" "control-plane" "⚙️ Operator"

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│  👁️  Labeling MONITORING (Observers)                         │"
echo "└──────────────────────────────────────────────────────────────┘"

patch_deployment "prometheus" "monitoring" \
    "observer" "metrics" "infrastructure" "monitoring" "👁️ Prometheus"

patch_deployment "grafana" "monitoring" \
    "observer" "dashboard" "infrastructure" "monitoring" "👁️ Grafana"

patch_deployment "loki" "monitoring" \
    "observer" "logs" "infrastructure" "monitoring" "👁️ Loki"

patch_deployment "weave-scope" "weave" \
    "observer" "visualization" "infrastructure" "monitoring" "👁️ Weave Scope"

echo ""
echo "┌──────────────────────────────────────────────────────────────┐"
echo "│  ✓ Labeling LEGITIMATE SERVICES (Protected)                  │"
echo "└──────────────────────────────────────────────────────────────┘"

patch_deployment "ecommerce-frontend" "deception-system" \
    "legitimate" "frontend" "protected" "application" "✓ Frontend"

patch_deployment "ecommerce-api" "deception-system" \
    "legitimate" "api" "protected" "application" "✓ API"

patch_deployment "ecommerce-db" "deception-system" \
    "legitimate" "database" "protected" "application" "✓ Database"

echo ""
echo "════════════════════════════════════════════════════════════════"
echo ""
log_info "Label injection complete!"
echo ""
echo "Labels applied (use for filtering in Scope):"
echo "  scope.weave.works/role: honeypot|controller|observer|legitimate"
echo "  scope.weave.works/risk: decoy|infrastructure|protected"
echo "  scope.weave.works/category: deception|monitoring|application"
echo ""
echo "View in Weave Scope:"
echo "  kubectl port-forward svc/weave-scope 4040:80 -n weave"
echo "  Open: http://localhost:4040"
echo ""
