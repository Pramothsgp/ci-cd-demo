#!/bin/bash

# =============================================================================
# Minikube Setup Script for CI/CD Demo
# =============================================================================

set -e

echo "🚀 Setting up Minikube for CI/CD Demo..."

# Configuration
MINIKUBE_CPUS=${MINIKUBE_CPUS:-4}
MINIKUBE_MEMORY=${MINIKUBE_MEMORY:-8192}
MINIKUBE_DRIVER=${MINIKUBE_DRIVER:-docker}
CLUSTER_NAME=${CLUSTER_NAME:-ci-cd-demo}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."
    
    # Check minikube
    if ! command -v minikube &> /dev/null; then
        print_error "minikube is not installed. Please install it first."
        echo "Installation: https://minikube.sigs.k8s.io/docs/start/"
        exit 1
    fi
    
    # Check kubectl
    if ! command -v kubectl &> /dev/null; then
        print_error "kubectl is not installed. Please install it first."
        exit 1
    fi
    
    # Check docker (if using docker driver)
    if [ "$MINIKUBE_DRIVER" == "docker" ]; then
        if ! command -v docker &> /dev/null; then
            print_error "Docker is not installed. Please install it first."
            exit 1
        fi
        
        if ! docker info &> /dev/null; then
            print_error "Docker daemon is not running. Please start Docker."
            exit 1
        fi
    fi
    
    print_status "All prerequisites met ✓"
}

# Start Minikube
start_minikube() {
    print_status "Starting Minikube cluster..."
    
    # Check if cluster already exists
    if minikube status -p $CLUSTER_NAME &> /dev/null; then
        print_warning "Cluster '$CLUSTER_NAME' already exists."
        read -p "Do you want to delete and recreate it? (y/N) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            minikube delete -p $CLUSTER_NAME
        else
            print_status "Using existing cluster..."
            minikube start -p $CLUSTER_NAME
            return
        fi
    fi
    
    # Start new cluster
    minikube start \
        -p $CLUSTER_NAME \
        --cpus=$MINIKUBE_CPUS \
        --memory=$MINIKUBE_MEMORY \
        --driver=$MINIKUBE_DRIVER \
        --kubernetes-version=stable \
        --addons=metrics-server \
        --addons=dashboard
    
    print_status "Minikube cluster started ✓"
}

# Enable addons
enable_addons() {
    print_status "Enabling Minikube addons..."
    
    minikube addons enable ingress -p $CLUSTER_NAME
    minikube addons enable ingress-dns -p $CLUSTER_NAME
    minikube addons enable metrics-server -p $CLUSTER_NAME
    minikube addons enable dashboard -p $CLUSTER_NAME
    
    print_status "Addons enabled ✓"
}

# Wait for ingress controller
wait_for_ingress() {
    print_status "Waiting for NGINX Ingress Controller to be ready..."
    
    kubectl wait --namespace ingress-nginx \
        --for=condition=ready pod \
        --selector=app.kubernetes.io/component=controller \
        --timeout=120s || true
    
    print_status "Ingress Controller ready ✓"
}

# Configure hosts file
configure_hosts() {
    print_status "Configuring /etc/hosts..."
    
    MINIKUBE_IP=$(minikube ip -p $CLUSTER_NAME)
    
    echo ""
    echo "Please add the following entries to your /etc/hosts file:"
    echo ""
    echo "  $MINIKUBE_IP demo.local"
    echo "  $MINIKUBE_IP users.demo.local"
    echo "  $MINIKUBE_IP orders.demo.local"
    echo "  $MINIKUBE_IP argocd.demo.local"
    echo ""
    echo "Run: sudo nano /etc/hosts"
    echo ""
}

# Setup Docker environment
setup_docker_env() {
    print_status "Setting up Docker environment..."
    
    echo ""
    echo "To use Minikube's Docker daemon, run:"
    echo ""
    echo "  eval \$(minikube -p $CLUSTER_NAME docker-env)"
    echo ""
    echo "This allows you to build images directly in Minikube."
    echo ""
}

# Print summary
print_summary() {
    echo ""
    echo "=============================================="
    echo "🎉 Minikube Setup Complete!"
    echo "=============================================="
    echo ""
    echo "Cluster Name: $CLUSTER_NAME"
    echo "Minikube IP:  $(minikube ip -p $CLUSTER_NAME)"
    echo ""
    echo "Useful commands:"
    echo "  minikube dashboard -p $CLUSTER_NAME    # Open K8s dashboard"
    echo "  minikube tunnel -p $CLUSTER_NAME       # Expose LoadBalancer services"
    echo "  minikube stop -p $CLUSTER_NAME         # Stop the cluster"
    echo "  minikube delete -p $CLUSTER_NAME       # Delete the cluster"
    echo ""
    echo "Next steps:"
    echo "  1. Add hosts entries (see above)"
    echo "  2. Run: ./scripts/setup-argocd.sh"
    echo "  3. Deploy: kubectl apply -k k8s/overlays/dev"
    echo ""
}

# Main
main() {
    check_prerequisites
    start_minikube
    enable_addons
    wait_for_ingress
    configure_hosts
    setup_docker_env
    print_summary
}

main "$@"
