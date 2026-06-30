#!/bin/bash

# =============================================================================
# Monitoring Setup Script
# =============================================================================

set -e

echo "🚀 Setting up monitoring stack (Prometheus + Grafana)..."

# Colors
GREEN='\033[0;32m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

# Create namespace
print_status "Creating monitoring namespace..."
kubectl create namespace monitoring --dry-run=client -o yaml | kubectl apply -f -

# Apply Prometheus config
print_status "Deploying Prometheus..."
kubectl apply -f monitoring/prometheus/prometheus-config.yaml
kubectl apply -f monitoring/prometheus/deployment.yaml

# Apply Grafana
print_status "Deploying Grafana..."
kubectl apply -f monitoring/grafana/deployment.yaml

# Wait for pods
print_status "Waiting for monitoring pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n monitoring --timeout=120s

# Print access info
echo ""
echo "=============================================="
echo "🎉 Monitoring Setup Complete!"
echo "=============================================="
echo ""
echo "Access Prometheus:"
echo "  kubectl port-forward svc/prometheus 9090:9090 -n monitoring"
echo "  Open: http://localhost:9090"
echo ""
echo "Access Grafana:"
echo "  kubectl port-forward svc/grafana 3000:3000 -n monitoring"
echo "  Open: http://localhost:3000"
echo "  Username: admin"
echo "  Password: admin123"
echo ""
