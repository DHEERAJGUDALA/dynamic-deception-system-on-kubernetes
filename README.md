# Dynamic Deception System for Kubernetes

A lightweight, configurable honeypot and deception system designed to detect and analyze malicious activity in Kubernetes environments.

## Resource Profiles

| Profile | RAM Allocation | CPU Cores | Best For |
|---------|---------------|-----------|----------|
| Light   | 4GB           | 2         | Raspberry Pi, VMs, testing |
| Medium  | 6GB           | 4         | **i3 laptops (8GB total)**, small servers |
| Heavy   | 8GB           | 6+        | Production, dedicated servers |

## Quick Start

```bash
# For i3 laptop with 8GB RAM (recommended)
./scripts/setup-medium.sh

# For low-resource environments
./scripts/setup-light.sh

# For dedicated servers
./scripts/setup-heavy.sh
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Kubernetes Cluster                        │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ SSH Honeypot│  │HTTP Honeypot│  │ DB Honeypot │          │
│  │   (Python)  │  │  (Python)   │  │  (Python)   │          │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘          │
│         │                │                │                  │
│         └────────────────┼────────────────┘                  │
│                          ▼                                   │
│              ┌───────────────────────┐                       │
│              │  Deception Operator   │                       │
│              │        (Go)           │                       │
│              └───────────┬───────────┘                       │
│                          ▼                                   │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐          │
│  │ Prometheus  │  │    Loki     │  │   Grafana   │          │
│  └─────────────┘  └─────────────┘  └─────────────┘          │
│                          │                                   │
│              ┌───────────▼───────────┐                       │
│              │     Weave Scope       │                       │
│              │    (Visualization)    │                       │
│              └───────────────────────┘                       │
└─────────────────────────────────────────────────────────────┘
```

## Memory Optimization Guide

### For i3 with 8GB RAM (Medium Profile)

The medium profile is specifically optimized for Intel i3 processors with 8GB total system RAM:

1. **System Reserve**: 2GB for OS and background processes
2. **Kubernetes Overhead**: ~1GB for kubelet, containerd
3. **Deception System**: 5GB allocated as follows:
   - Honeypots: 512MB total (128MB each × 4)
   - Operator: 128MB
   - Prometheus: 512MB
   - Loki: 256MB
   - Grafana: 256MB
   - Weave Scope: 384MB (reduced)

### Resource Limits by Profile

| Component      | Light  | Medium | Heavy  |
|----------------|--------|--------|--------|
| SSH Honeypot   | 64MB   | 128MB  | 256MB  |
| HTTP Honeypot  | 64MB   | 128MB  | 256MB  |
| DB Honeypot    | 64MB   | 128MB  | 256MB  |
| SMTP Honeypot  | 64MB   | 128MB  | 256MB  |
| Operator       | 64MB   | 128MB  | 256MB  |
| Prometheus     | 256MB  | 512MB  | 1GB    |
| Loki           | 128MB  | 256MB  | 512MB  |
| Grafana        | 128MB  | 256MB  | 512MB  |
| Weave Scope    | 256MB  | 384MB  | 512MB  |

## Components

### 1. Honeypots (Python - Lightweight)

All honeypots are implemented in Python with minimal dependencies:

- **SSH Honeypot**: Emulates SSH server, captures credentials
- **HTTP Honeypot**: Fake web services, captures requests
- **Database Honeypot**: Emulates MySQL/PostgreSQL protocols
- **SMTP Honeypot**: Captures email attempts

### 2. Deception Operator (Go)

Custom Kubernetes operator that:
- Manages honeypot lifecycle
- Rotates decoy credentials
- Handles dynamic IP allocation
- Manages canary tokens

### 3. Monitoring Stack

- **Prometheus**: Metrics collection (optimized retention)
- **Loki**: Log aggregation (compressed storage)
- **Grafana**: Dashboards (pre-configured alerts)

### 4. Weave Scope (Optimized)

Network visualization with reduced resource footprint:
- Disabled real-time updates (5s polling)
- Reduced history retention
- CPU throttling enabled

## Directory Structure

```
deception-system/
├── configs/
│   ├── light/          # 4GB RAM allocation
│   ├── medium/         # 6GB RAM allocation (i3 optimized)
│   └── heavy/          # 8GB RAM allocation
├── operator/           # Go operator code
├── honeypots/          # Python implementations
│   ├── ssh/
│   ├── http/
│   ├── database/
│   └── smtp/
├── ecommerce/          # Demo target services
├── monitoring/         # Prometheus, Loki, Grafana
├── weave-scope/        # Optimized visualization
└── scripts/            # Setup scripts
```

## Configuration

### Environment Variables

```bash
# Profile selection
DECEPTION_PROFILE=medium  # light, medium, heavy

# Honeypot ports
SSH_HONEYPOT_PORT=2222
HTTP_HONEYPOT_PORT=8080
DB_HONEYPOT_PORT=3306
SMTP_HONEYPOT_PORT=2525

# Logging
LOG_LEVEL=INFO
LOG_FORMAT=json
```

## Alerts

The system generates alerts for:

1. **SSH Brute Force**: Multiple failed login attempts
2. **SQL Injection**: Detected injection patterns
3. **Port Scanning**: Systematic port probing
4. **Credential Stuffing**: Known leaked credentials
5. **Lateral Movement**: Internal IP accessing honeypots

## Development

```bash
# Build operator
cd operator && go build -o bin/operator ./cmd/

# Build honeypot images
docker build -t honeypot-ssh ./honeypots/ssh/
docker build -t honeypot-http ./honeypots/http/

# Run tests
go test ./...
python -m pytest honeypots/
```

## License

MIT License - See LICENSE file
