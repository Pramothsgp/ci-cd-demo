#!/bin/bash

# =============================================================================
# NGINX Ingress Setup Script
# =============================================================================

set -e

echo "🚀 Setting up NGINX Ingress Controller..."

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

# Check if running in Minikube
is_minikube() {
    kubectl config current-context | grep -q "minikube"
}

# Enable Minikube ingress addon
setup_minikube_ingress() {
    print_status "Enabling Minikube NGINX Ingress addon..."
    
    minikube addons enable ingress
    minikube addons enable ingress-dns
    
    print_status "Waiting for Ingress Controller to be ready..."
    
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=180s
    
    print_status "Minikube Ingress enabled ✓"
}

# Install NGINX Ingress Controller via Helm (for non-Minikube)
setup_helm_ingress() {
    print_status "Installing NGINX Ingress Controller via Helm..."
    
    # Add Helm repo
    helm repo add ingress-nginx https://kubernetes.github.io/ingress-nginx
    helm repo update
    
    # Install
    helm install ingress-nginx ingress-nginx/ingress-nginx \
        --namespace ingress-nginx \
        --create-namespace \
        --set controller.replicaCount=2 \
        --set controller.metrics.enabled=true \
        --set controller.metrics.serviceMonitor.enabled=false
    
    print_status "Waiting for Ingress Controller to be ready..."
    
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=180s
    
    print_status "Helm Ingress installed ✓"
}

# Configure custom NGINX settings
configure_nginx() {
    print_status "Applying custom NGINX configuration..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: nginx-configuration
  namespace: ingress-nginx
data:
  # Load balancing
  load-balance: "round_robin"
  
  # Proxy settings
  proxy-connect-timeout: "30"
  proxy-read-timeout: "30"
  proxy-send-timeout: "30"
  
  # Keep-alive
  upstream-keepalive-connections: "32"
  upstream-keepalive-timeout: "60"
  
  # Logging
  log-format-upstream: '\$remote_addr - \$remote_user [\$time_local] "\$request" \$status \$body_bytes_sent "\$http_referer" "\$http_user_agent" \$request_length \$request_time [\$proxy_upstream_name] \$upstream_addr \$upstream_response_length \$upstream_response_time \$upstream_status'
  
  # Security headers
  add-headers: "ingress-nginx/custom-headers"
EOF

    # Custom headers
    cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: ConfigMap
metadata:
  name: custom-headers
  namespace: ingress-nginx
data:
  X-Frame-Options: "SAMEORIGIN"
  X-Content-Type-Options: "nosniff"
  X-XSS-Protection: "1; mode=block"
EOF

    print_status "NGINX configured ✓"
}

# Verify installation
verify_installation() {
    print_status "Verifying Ingress installation..."
    
    echo ""
    echo "Ingress Controller Pods:"
    kubectl get pods -n ingress-nginx
    
    echo ""
    echo "Ingress Controller Service:"
    kubectl get svc -n ingress-nginx
    
    echo ""
}

# Print summary
print_summary() {
    MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "See LoadBalancer EXTERNAL-IP")
    
    echo ""
    echo "=============================================="
    echo "🎉 NGINX Ingress Setup Complete!"
    echo "=============================================="
    echo ""
    echo "Ingress IP: $MINIKUBE_IP"
    echo ""
    echo "To use Ingress:"
    echo "  1. Create Ingress resources in your deployments"
    echo "  2. Add hosts to /etc/hosts pointing to $MINIKUBE_IP"
    echo "  3. Access services via configured hostnames"
    echo ""
    echo "For Minikube tunnel (LoadBalancer services):"
    echo "  minikube tunnel"
    echo ""
}

# Main
main() {
    if is_minikube; then
        setup_minikube_ingress
    else
        if command -v helm &> /dev/null; then
            setup_helm_ingress
        else
            print_warning "Helm not found. Installing via kubectl..."
            kubectl apply -f https://raw.githubusercontent.com/kubernetes/ingress-nginx/controller-v1.9.4/deploy/static/provider/cloud/deploy.yaml
        fi
    fi
    
    configure_nginx
    verify_installation
    print_summary
}

main "$@"
