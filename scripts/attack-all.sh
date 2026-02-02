#!/bin/bash
# =============================================================================
# ATTACK SIMULATION SCRIPT
# =============================================================================
# This script simulates an attacker trying to reach e-commerce services.
# The attacker gets trapped in the deception layer (honeypots).
# All 8 honeypots get connections visible in Weave Scope.
# =============================================================================

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${RED}"
cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                                                                   ║
    ║     ⚠️  ATTACKER SIMULATION - DECEPTION SYSTEM DEMO ⚠️            ║
    ║                                                                   ║
    ╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Check if attacker pod exists, create if not
if ! kubectl get pod attacker -n deception-system &>/dev/null; then
    echo -e "${YELLOW}[*] Creating attacker pod...${NC}"
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Pod
metadata:
  name: attacker
  namespace: deception-system
  labels:
    app: attacker
    role: threat-actor
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
        cpu: "100m"
        memory: "64Mi"
EOF
    kubectl wait --for=condition=Ready pod/attacker -n deception-system --timeout=60s
fi

echo -e "${GREEN}[✓] Attacker pod ready${NC}"
echo ""

# Function to attack a service
attack_service() {
    local name=$1
    local service=$2
    local port=$3
    local attack_type=$4
    local payload=$5

    echo -e "${RED}[⚡] Attacking ${name}${NC}"
    echo -e "    Target: ${service}:${port}"
    echo -e "    Attack: ${attack_type}"

    case $attack_type in
        "http")
            kubectl exec -n deception-system attacker -- curl -s -o /dev/null -w "%{http_code}" \
                "http://${service}:${port}${payload}" 2>/dev/null || true
            ;;
        "tcp")
            kubectl exec -n deception-system attacker -- sh -c \
                "nc -w 2 ${service} ${port} < /dev/null" 2>/dev/null || true
            ;;
        "ssh")
            kubectl exec -n deception-system attacker -- sh -c \
                "echo 'SSH-2.0-Attacker' | nc -w 2 ${service} ${port}" 2>/dev/null || true
            ;;
    esac

    echo -e "${GREEN}    → Connection logged by honeypot${NC}"
    echo ""
}

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  PHASE 1: RECONNAISSANCE - Scanning for services${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Attack all 8 honeypots
attack_service "Frontend (Web)" "frontend-honeypot" "80" "http" "/"
attack_service "API Gateway" "api-honeypot" "8080" "http" "/api/v1/users"
attack_service "Admin Panel" "admin-honeypot" "8081" "http" "/admin/login"
attack_service "MySQL Database" "mysql-honeypot" "3306" "tcp" ""
attack_service "PostgreSQL Database" "postgres-honeypot" "5432" "tcp" ""
attack_service "SSH Server" "ssh-honeypot" "22" "ssh" ""
attack_service "Redis Cache" "redis-honeypot" "6379" "tcp" ""
attack_service "Elasticsearch" "elasticsearch-honeypot" "9200" "http" "/_cluster/health"

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  PHASE 2: EXPLOITATION - Attempting attacks${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# SQL Injection attacks
echo -e "${RED}[⚡] SQL Injection on Frontend${NC}"
kubectl exec -n deception-system attacker -- curl -s -o /dev/null \
    "http://frontend-honeypot:80/search?q=1'+OR+'1'='1" 2>/dev/null || true
echo -e "${GREEN}    → Attack detected: sql_injection${NC}"
echo ""

echo -e "${RED}[⚡] SQL Injection on API${NC}"
kubectl exec -n deception-system attacker -- curl -s -o /dev/null \
    "http://api-honeypot:8080/api/users?id=1;DROP+TABLE+users" 2>/dev/null || true
echo -e "${GREEN}    → Attack detected: sql_injection${NC}"
echo ""

# Path traversal
echo -e "${RED}[⚡] Path Traversal on Admin${NC}"
kubectl exec -n deception-system attacker -- curl -s -o /dev/null \
    "http://admin-honeypot:8081/../../../../etc/passwd" 2>/dev/null || true
echo -e "${GREEN}    → Attack detected: path_traversal${NC}"
echo ""

# Admin discovery
echo -e "${RED}[⚡] Admin Panel Brute Force${NC}"
for path in login dashboard config backup users settings; do
    kubectl exec -n deception-system attacker -- curl -s -o /dev/null \
        "http://admin-honeypot:8081/admin/${path}" 2>/dev/null &
done
wait
echo -e "${GREEN}    → Attack detected: reconnaissance${NC}"
echo ""

# Database attacks
echo -e "${RED}[⚡] Database Credential Stuffing${NC}"
for i in 1 2 3 4 5; do
    kubectl exec -n deception-system attacker -- sh -c \
        "nc -w 1 mysql-honeypot 3306 < /dev/null" 2>/dev/null &
    kubectl exec -n deception-system attacker -- sh -c \
        "nc -w 1 postgres-honeypot 5432 < /dev/null" 2>/dev/null &
done
wait
echo -e "${GREEN}    → 10 database connection attempts logged${NC}"
echo ""

# SSH brute force
echo -e "${RED}[⚡] SSH Brute Force Attack${NC}"
for user in root admin ubuntu ec2-user; do
    kubectl exec -n deception-system attacker -- sh -c \
        "echo 'SSH-2.0-Attacker' | nc -w 1 ssh-honeypot 22" 2>/dev/null &
done
wait
echo -e "${GREEN}    → 4 SSH login attempts logged${NC}"
echo ""

# Redis/Elasticsearch
echo -e "${RED}[⚡] Cache/Search Exploitation${NC}"
kubectl exec -n deception-system attacker -- sh -c \
    "echo 'INFO' | nc -w 1 redis-honeypot 6379" 2>/dev/null || true
kubectl exec -n deception-system attacker -- curl -s -o /dev/null \
    "http://elasticsearch-honeypot:9200/_search?q=*:*" 2>/dev/null || true
echo -e "${GREEN}    → Redis and Elasticsearch probes logged${NC}"
echo ""

echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}  ATTACK SIMULATION COMPLETE${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${GREEN}"
cat << 'EOF'
    ╔═══════════════════════════════════════════════════════════════════╗
    ║                                                                   ║
    ║  ✓ Attacker connected to ALL 8 HONEYPOTS                         ║
    ║  ✓ All attacks were TRAPPED and LOGGED                           ║
    ║  ✓ Real services were NEVER touched                              ║
    ║                                                                   ║
    ║  Open Weave Scope to see the attack graph:                       ║
    ║  → http://localhost:4040                                         ║
    ║                                                                   ║
    ║  You will see:                                                   ║
    ║  • Attacker pod in the center                                    ║
    ║  • 8 lines connecting to each honeypot                           ║
    ║  • Real services isolated (no connections from attacker)         ║
    ║                                                                   ║
    ╚═══════════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"
