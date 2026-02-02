#!/bin/bash
#═══════════════════════════════════════════════════════════════════════════════
#  DYNAMIC DECEPTION SYSTEM - PROFESSIONAL DEMO SCRIPT
#═══════════════════════════════════════════════════════════════════════════════
#
#  This script provides a polished, professional demonstration of the
#  Kubernetes honeypot deception system with Weave Scope visualization.
#
#  Features:
#  - 3 Honeypots (SSH, HTTP, MySQL)
#  - 5 E-commerce services (Frontend, API, Products, Orders, Database)
#  - Real-time attack visualization in Weave Scope
#  - Multiple attack scenarios
#
#═══════════════════════════════════════════════════════════════════════════════

set -e

# Colors for professional output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m' # No Color
BOLD='\033[1m'

# Clear screen and show banner
clear_and_banner() {
    clear
    echo -e "${CYAN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════════╗
    ║                                                                       ║
    ║     ██████╗ ███████╗ ██████╗███████╗██████╗ ████████╗██╗ ██████╗ ███╗ ║
    ║     ██╔══██╗██╔════╝██╔════╝██╔════╝██╔══██╗╚══██╔══╝██║██╔═══██╗████╗║
    ║     ██║  ██║█████╗  ██║     █████╗  ██████╔╝   ██║   ██║██║   ██║██╔██║
    ║     ██║  ██║██╔══╝  ██║     ██╔══╝  ██╔═══╝    ██║   ██║██║   ██║██║╚█║
    ║     ██████╔╝███████╗╚██████╗███████╗██║        ██║   ██║╚██████╔╝██║ █║
    ║     ╚═════╝ ╚══════╝ ╚═════╝╚══════╝╚═╝        ╚═╝   ╚═╝ ╚═════╝ ╚═╝ ╚║
    ║                                                                       ║
    ║              DYNAMIC DECEPTION SYSTEM FOR KUBERNETES                  ║
    ║                                                                       ║
    ╚═══════════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Logging functions
log_info() { echo -e "${GREEN}[✓]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[!]${NC} $1"; }
log_error() { echo -e "${RED}[✗]${NC} $1"; }
log_step() { echo -e "${BLUE}[→]${NC} $1"; }
log_attack() { echo -e "${RED}[⚡]${NC} ${RED}$1${NC}"; }

# Section header
section() {
    echo ""
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${PURPLE}  $1${NC}"
    echo -e "${PURPLE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo ""
}

# Wait for user
pause() {
    echo ""
    echo -e "${WHITE}Press ENTER to continue...${NC}"
    read -r
}

# Check prerequisites
check_prereqs() {
    section "🔍 CHECKING PREREQUISITES"

    log_step "Checking kubectl..."
    kubectl version --client > /dev/null 2>&1 && log_info "kubectl installed" || { log_error "kubectl not found"; exit 1; }

    log_step "Checking minikube..."
    minikube status > /dev/null 2>&1 && log_info "minikube running" || { log_error "minikube not running"; exit 1; }

    log_step "Checking cluster connectivity..."
    kubectl get nodes > /dev/null 2>&1 && log_info "Cluster accessible" || { log_error "Cannot connect to cluster"; exit 1; }
}

# Show system architecture
show_architecture() {
    section "🏗️  SYSTEM ARCHITECTURE"

    echo -e "${WHITE}"
    cat << 'EOF'
    ┌─────────────────────────────────────────────────────────────────────┐
    │                        DECEPTION ARCHITECTURE                        │
    ├─────────────────────────────────────────────────────────────────────┤
    │                                                                      │
    │   ATTACKER                                                           │
    │      │                                                               │
    │      ▼                                                               │
    │   ┌──────────────────────────────────────────────────────────────┐  │
    │   │                    DECEPTION LAYER                            │  │
    │   │  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐      │  │
    │   │  │   🍯    │   │   🍯    │   │   🍯    │   │   🍯    │      │  │
    │   │  │  SSH    │   │  HTTP   │   │  MySQL  │   │  SMTP   │      │  │
    │   │  │ :2222   │   │ :8080   │   │ :3306   │   │  :25    │      │  │
    │   │  └─────────┘   └─────────┘   └─────────┘   └─────────┘      │  │
    │   └──────────────────────────────────────────────────────────────┘  │
    │                                                                      │
    │   ┌──────────────────────────────────────────────────────────────┐  │
    │   │                    LEGITIMATE SERVICES                        │  │
    │   │  ┌─────────┐   ┌─────────┐   ┌─────────┐   ┌─────────┐      │  │
    │   │  │   ✓     │   │   ✓     │   │   ✓     │   │   ✓     │      │  │
    │   │  │Frontend │   │   API   │   │Products │   │ Orders  │      │  │
    │   │  │  :80    │   │ :8081   │   │ :8082   │   │ :8083   │      │  │
    │   │  └─────────┘   └─────────┘   └─────────┘   └─────────┘      │  │
    │   │                      │                                        │  │
    │   │                ┌─────▼─────┐                                 │  │
    │   │                │PostgreSQL │                                 │  │
    │   │                │   :5432   │                                 │  │
    │   │                └───────────┘                                 │  │
    │   └──────────────────────────────────────────────────────────────┘  │
    │                                                                      │
    │   ┌──────────────────────────────────────────────────────────────┐  │
    │   │                      MONITORING                               │  │
    │   │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │  │
    │   │  │ 👁️ Weave    │  │ 👁️ Prometheus│  │ 👁️ Grafana  │          │  │
    │   │  │   Scope     │  │   Metrics    │  │  Dashboard  │          │  │
    │   │  └─────────────┘  └─────────────┘  └─────────────┘          │  │
    │   └──────────────────────────────────────────────────────────────┘  │
    │                                                                      │
    └─────────────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"
}

# Show running components
show_components() {
    section "📦 RUNNING COMPONENTS"

    echo -e "${YELLOW}🍯 HONEYPOTS (Decoy Systems):${NC}"
    kubectl get pods -n deception-system -l component=honeypot 2>/dev/null || \
    kubectl get pods -n deception-system | grep -E "(ssh|http|db)-honeypot" | awk '{print "   "$1" - "$3}'

    echo ""
    echo -e "${GREEN}✓ E-COMMERCE (Legitimate Services):${NC}"
    kubectl get pods -n deception-system -l component=ecommerce 2>/dev/null || \
    kubectl get pods -n deception-system | grep -E "(ecommerce|product|order)" | awk '{print "   "$1" - "$3}'

    echo ""
    echo -e "${CYAN}👁️ MONITORING:${NC}"
    kubectl get pods -n weave 2>/dev/null | grep -v NAME | awk '{print "   "$1" - "$3}'
    kubectl get pods -n monitoring 2>/dev/null | grep -v NAME | awk '{print "   "$1" - "$3}'
}

# Start Weave Scope
start_weave_scope() {
    section "👁️  STARTING WEAVE SCOPE VISUALIZATION"

    # Kill existing port-forwards
    pkill -f "port-forward.*weave-scope" 2>/dev/null || true
    sleep 1

    log_step "Starting port-forward to Weave Scope..."
    kubectl port-forward svc/weave-scope 4040:80 -n weave > /dev/null 2>&1 &
    sleep 3

    # Verify connection
    if curl -s http://localhost:4040/api > /dev/null 2>&1; then
        log_info "Weave Scope is running!"
        echo ""
        echo -e "${WHITE}┌───────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${WHITE}│                                                                   │${NC}"
        echo -e "${WHITE}│   ${GREEN}🌐 WEAVE SCOPE UI: ${BOLD}http://localhost:4040${NC}${WHITE}                     │${NC}"
        echo -e "${WHITE}│                                                                   │${NC}"
        echo -e "${WHITE}│   ${CYAN}Open this URL in your browser to see the topology${NC}${WHITE}             │${NC}"
        echo -e "${WHITE}│                                                                   │${NC}"
        echo -e "${WHITE}└───────────────────────────────────────────────────────────────────┘${NC}"
    else
        log_warn "Weave Scope may take a moment to start..."
    fi
}

# Create attacker pod
setup_attacker() {
    section "🔴 SETTING UP ATTACKER SIMULATION"

    # Delete existing attacker
    kubectl delete pod attacker -n deception-system --ignore-not-found=true > /dev/null 2>&1

    log_step "Creating attacker pod..."
    cat <<EOF | kubectl apply -f - > /dev/null 2>&1
apiVersion: v1
kind: Pod
metadata:
  name: attacker
  namespace: deception-system
  labels:
    app: attacker
    scope.weave.works/role: attacker
    scope.weave.works/risk: malicious
    scope.weave.works/category: threat
spec:
  containers:
  - name: attacker
    image: curlimages/curl:latest
    command: ["sleep", "3600"]
    resources:
      requests:
        cpu: "10m"
        memory: "32Mi"
      limits:
        cpu: "50m"
        memory: "64Mi"
EOF

    kubectl wait --for=condition=Ready pod/attacker -n deception-system --timeout=60s > /dev/null 2>&1
    log_info "Attacker pod ready"
}

# Attack demonstration functions
attack_http_sqli() {
    log_attack "SQL INJECTION ATTACK"
    echo -e "   ${WHITE}Target: HTTP Honeypot (:8080)${NC}"
    echo -e "   ${WHITE}Payload: ' OR '1'='1${NC}"
    kubectl exec -n deception-system attacker -- curl -s -o /dev/null \
        "http://http-honeypot:8080/login?user=admin'--&pass=x"
    kubectl exec -n deception-system attacker -- curl -s -o /dev/null \
        "http://http-honeypot:8080/search?q=1'+OR+'1'='1"
    kubectl exec -n deception-system attacker -- curl -s -o /dev/null \
        "http://http-honeypot:8080/api?id=1;+DROP+TABLE+users--"
    log_info "3 SQL injection attempts sent"
}

attack_http_traversal() {
    log_attack "PATH TRAVERSAL ATTACK"
    echo -e "   ${WHITE}Target: HTTP Honeypot (:8080)${NC}"
    echo -e "   ${WHITE}Payload: ../../../../etc/passwd${NC}"
    kubectl exec -n deception-system attacker -- curl -s -o /dev/null \
        "http://http-honeypot:8080/../../../../etc/passwd"
    kubectl exec -n deception-system attacker -- curl -s -o /dev/null \
        "http://http-honeypot:8080/..%2f..%2f..%2fetc/shadow"
    log_info "2 path traversal attempts sent"
}

attack_http_recon() {
    log_attack "RECONNAISSANCE ATTACK"
    echo -e "   ${WHITE}Target: HTTP Honeypot (:8080)${NC}"
    echo -e "   ${WHITE}Probing: /admin, /wp-admin, /.git, /.env${NC}"
    for path in admin wp-admin phpmyadmin .git/config .env robots.txt; do
        kubectl exec -n deception-system attacker -- curl -s -o /dev/null \
            "http://http-honeypot:8080/$path" &
    done
    wait
    log_info "6 reconnaissance probes sent"
}

attack_http_xss() {
    log_attack "CROSS-SITE SCRIPTING (XSS) ATTACK"
    echo -e "   ${WHITE}Target: HTTP Honeypot (:8080)${NC}"
    echo -e "   ${WHITE}Payload: <script>alert(1)</script>${NC}"
    kubectl exec -n deception-system attacker -- curl -s -o /dev/null \
        "http://http-honeypot:8080/comment?text=%3Cscript%3Ealert(1)%3C/script%3E"
    log_info "XSS payload sent"
}

attack_mysql() {
    log_attack "DATABASE PROBE ATTACK"
    echo -e "   ${WHITE}Target: MySQL Honeypot (:3306)${NC}"
    echo -e "   ${WHITE}Attempting unauthorized database connections${NC}"
    for i in 1 2 3 4 5; do
        kubectl exec -n deception-system attacker -- sh -c \
            "nc -w 1 db-honeypot 3306 < /dev/null" 2>/dev/null &
    done
    wait
    log_info "5 MySQL connection attempts sent"
}

attack_ssh() {
    log_attack "SSH BRUTE FORCE ATTACK"
    echo -e "   ${WHITE}Target: SSH Honeypot (:2222)${NC}"
    echo -e "   ${WHITE}Attempting credential stuffing${NC}"
    for i in 1 2 3 4 5; do
        kubectl exec -n deception-system attacker -- sh -c \
            "echo 'SSH-2.0-OpenSSH_7.4' | nc -w 1 ssh-honeypot 2222" 2>/dev/null &
    done
    wait
    log_info "5 SSH brute force attempts sent"
}

# Run all attacks
run_all_attacks() {
    section "⚡ LAUNCHING ATTACK SIMULATION"

    echo -e "${RED}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                    ⚠️  ATTACK IN PROGRESS ⚠️                       ║
    ╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"

    sleep 1

    attack_http_sqli
    echo ""
    sleep 1

    attack_http_traversal
    echo ""
    sleep 1

    attack_http_recon
    echo ""
    sleep 1

    attack_http_xss
    echo ""
    sleep 1

    attack_mysql
    echo ""
    sleep 1

    attack_ssh
    echo ""

    echo -e "${GREEN}"
    cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                  ✓ ATTACK SIMULATION COMPLETE                     ║
    ╚═══════════════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Show attack logs
show_logs() {
    section "📋 HONEYPOT DETECTION LOGS"

    echo -e "${YELLOW}HTTP Honeypot Logs (last 10 entries):${NC}"
    kubectl logs -n deception-system deployment/http-honeypot --tail=10 2>/dev/null || echo "   No logs available"

    echo ""
    echo -e "${YELLOW}SSH Honeypot Logs (last 5 entries):${NC}"
    kubectl logs -n deception-system deployment/ssh-honeypot --tail=5 2>/dev/null || echo "   No logs available"

    echo ""
    echo -e "${YELLOW}MySQL Honeypot Logs (last 5 entries):${NC}"
    kubectl logs -n deception-system deployment/db-honeypot --tail=5 2>/dev/null || echo "   No logs available"
}

# Summary
show_summary() {
    section "📊 DEMO SUMMARY"

    echo -e "${WHITE}"
    cat << 'EOF'
    ┌───────────────────────────────────────────────────────────────────┐
    │                      WHAT YOU JUST SAW                            │
    ├───────────────────────────────────────────────────────────────────┤
    │                                                                   │
    │  🍯 HONEYPOTS DEPLOYED:                                          │
    │     • SSH Honeypot     - Captured brute force attempts           │
    │     • HTTP Honeypot    - Detected SQLi, XSS, path traversal      │
    │     • MySQL Honeypot   - Logged database probes                  │
    │                                                                   │
    │  ✓ LEGITIMATE SERVICES:                                          │
    │     • Frontend, API, Products, Orders, Database                  │
    │     • Clearly labeled as "protected" in topology                 │
    │                                                                   │
    │  👁️ MONITORING:                                                   │
    │     • Weave Scope - Real-time topology visualization             │
    │     • Prometheus  - Metrics collection                           │
    │                                                                   │
    │  ⚡ ATTACKS DEMONSTRATED:                                         │
    │     • SQL Injection       (3 attempts)                           │
    │     • Path Traversal      (2 attempts)                           │
    │     • Reconnaissance      (6 probes)                             │
    │     • XSS                 (1 payload)                            │
    │     • MySQL Probing       (5 connections)                        │
    │     • SSH Brute Force     (5 attempts)                           │
    │                                                                   │
    └───────────────────────────────────────────────────────────────────┘
EOF
    echo -e "${NC}"

    echo ""
    echo -e "${CYAN}View the attack topology at: ${BOLD}http://localhost:4040${NC}"
    echo ""
    echo -e "${WHITE}Filters to try in Weave Scope:${NC}"
    echo "   • label:scope.weave.works/role:honeypot    → Show honeypots"
    echo "   • label:scope.weave.works/role:attacker    → Show attacker"
    echo "   • label:scope.weave.works/role:legitimate  → Show real services"
    echo ""
}

# Interactive menu
show_menu() {
    echo ""
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════════${NC}"
    echo -e "${WHITE}                         DEMO OPTIONS                                  ${NC}"
    echo -e "${WHITE}═══════════════════════════════════════════════════════════════════════${NC}"
    echo ""
    echo "   1) Run full demo (recommended)"
    echo "   2) Show system architecture"
    echo "   3) Show running components"
    echo "   4) Launch attack simulation"
    echo "   5) View honeypot logs"
    echo "   6) Open Weave Scope"
    echo "   7) Cleanup and exit"
    echo ""
    echo -n "   Select option [1-7]: "
}

# Main function
main() {
    clear_and_banner

    case "${1:-menu}" in
        "full"|"--full")
            check_prereqs
            pause
            show_architecture
            pause
            show_components
            pause
            start_weave_scope
            pause
            setup_attacker
            pause
            run_all_attacks
            pause
            show_logs
            pause
            show_summary
            ;;
        "attack"|"--attack")
            setup_attacker
            run_all_attacks
            ;;
        "menu"|*)
            while true; do
                show_menu
                read -r choice
                case $choice in
                    1)
                        main "full"
                        break
                        ;;
                    2) show_architecture; pause ;;
                    3) show_components; pause ;;
                    4)
                        setup_attacker
                        run_all_attacks
                        pause
                        ;;
                    5) show_logs; pause ;;
                    6) start_weave_scope; pause ;;
                    7)
                        echo "Cleaning up..."
                        kubectl delete pod attacker -n deception-system --ignore-not-found=true
                        pkill -f "port-forward" 2>/dev/null || true
                        echo "Goodbye!"
                        exit 0
                        ;;
                    *) echo "Invalid option" ;;
                esac
                clear_and_banner
            done
            ;;
    esac
}

# Run
main "$@"
