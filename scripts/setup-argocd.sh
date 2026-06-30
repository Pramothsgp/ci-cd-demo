#!/bin/bash

# =============================================================================
# Argo CD Setup Script for CI/CD Demo
# =============================================================================

set -e

echo "🚀 Setting up Argo CD..."

# Configuration
ARGOCD_NAMESPACE=${ARGOCD_NAMESPACE:-argocd}
ARGOCD_VERSION=${ARGOCD_VERSION:-stable}

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check kubectl
check_kubectl() {
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed"
        exit 1
    fi
    
    if ! kubectl cluster-info &> /dev/null; then
        print_error "Cannot connect to Kubernetes cluster"
        exit 1
    fi
    
    print_status "kubectl configured ✓"
}

# Create namespace
create_namespace() {
    print_status "Creating Argo CD namespace..."
    
    kubectl create namespace $ARGOCD_NAMESPACE --dry-run=client -o yaml | kubectl apply -f -
    
    print_status "Namespace created ✓"
}

# Install Argo CD
install_argocd() {
    print_status "Installing Argo CD..."
    
    # Use --server-side to avoid the 262144-byte annotation limit on large CRDs
    kubectl apply -n $ARGOCD_NAMESPACE --server-side \
        -f https://raw.githubusercontent.com/argoproj/argo-cd/$ARGOCD_VERSION/manifests/install.yaml
    
    print_status "Argo CD manifests applied ✓"
}

# Wait for Argo CD to be ready
wait_for_argocd() {
    print_status "Waiting for Argo CD to be ready..."
    
    kubectl wait --for=condition=available --timeout=300s \
        deployment/argocd-server -n $ARGOCD_NAMESPACE
    
    kubectl wait --for=condition=Ready pods --all -n $ARGOCD_NAMESPACE --timeout=300s
    
    print_status "Argo CD is ready ✓"
}

# Get admin password
get_admin_password() {
    print_status "Retrieving admin password..."
    
    ARGOCD_PASSWORD=$(kubectl -n $ARGOCD_NAMESPACE get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" | base64 -d)
    
    echo ""
    echo "=============================================="
    echo "Argo CD Admin Credentials"
    echo "=============================================="
    echo "Username: admin"
    echo "Password: $ARGOCD_PASSWORD"
    echo "=============================================="
    echo ""
}

# Setup Ingress for Argo CD (optional)
setup_ingress() {
    print_status "Setting up Ingress for Argo CD..."
    
    cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: argocd-server-ingress
  namespace: $ARGOCD_NAMESPACE
  annotations:
    kubernetes.io/ingress.class: nginx
    nginx.ingress.kubernetes.io/ssl-passthrough: "true"
    nginx.ingress.kubernetes.io/backend-protocol: "HTTPS"
spec:
  ingressClassName: nginx
  rules:
    - host: argocd.demo.local
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: argocd-server
                port:
                  number: 443
EOF
    
    print_status "Ingress created ✓"
}

# Install Argo CD CLI (optional)
install_cli() {
    if command -v argocd &> /dev/null; then
        print_status "Argo CD CLI already installed"
        return
    fi
    
    print_status "Installing Argo CD CLI..."
    
    # Detect OS
    OS=$(uname -s | tr '[:upper:]' '[:lower:]')
    ARCH=$(uname -m)
    
    if [ "$ARCH" == "x86_64" ]; then
        ARCH="amd64"
    elif [ "$ARCH" == "aarch64" ]; then
        ARCH="arm64"
    fi
    
    # Download CLI
    curl -sSL -o /tmp/argocd https://github.com/argoproj/argo-cd/releases/latest/download/argocd-$OS-$ARCH
    
    # Install
    sudo install -m 555 /tmp/argocd /usr/local/bin/argocd
    rm /tmp/argocd
    
    print_status "Argo CD CLI installed ✓"
}

# Apply demo applications
apply_applications() {
    print_status "Applying demo applications..."
    
    # Check if application files exist
    if [ -d "../argocd/applications" ]; then
        kubectl apply -f ../argocd/applications/
        print_status "Applications applied ✓"
    else
        print_warning "No applications found in ../argocd/applications/"
    fi
}

# Print summary
print_summary() {
    MINIKUBE_IP=$(minikube ip 2>/dev/null || echo "localhost")
    
    echo ""
    echo "=============================================="
    echo "🎉 Argo CD Setup Complete!"
    echo "=============================================="
    echo ""
    echo "Access Argo CD UI:"
    echo ""
    echo "  Option 1 - Port Forward (recommended for demo):"
    echo "    kubectl port-forward svc/argocd-server -n $ARGOCD_NAMESPACE 8080:443"
    echo "    Open: https://localhost:8080"
    echo ""
    echo "  Option 2 - Ingress:"
    echo "    Add '$MINIKUBE_IP argocd.demo.local' to /etc/hosts"
    echo "    Open: https://argocd.demo.local"
    echo ""
    echo "Login:"
    echo "  Username: admin"
    echo "  Password: $ARGOCD_PASSWORD"
    echo ""
    echo "CLI Login:"
    echo "  argocd login localhost:8080 --username admin --password '$ARGOCD_PASSWORD' --insecure"
    echo ""
    echo "Next steps:"
    echo "  1. Access Argo CD UI"
    echo "  2. Connect your Git repository"
    echo "  3. Create/sync applications"
    echo ""
}

# Main
main() {
    check_kubectl
    create_namespace
    install_argocd
    wait_for_argocd
    get_admin_password
    setup_ingress
    # install_cli  # Uncomment to install CLI
    # apply_applications  # Uncomment to apply demo apps
    print_summary
}

main "$@"
