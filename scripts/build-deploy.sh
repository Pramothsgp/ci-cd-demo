#!/bin/bash

# =============================================================================
# Build and Deploy Script for Local Development
# =============================================================================

set -e

echo "🚀 Building and deploying services locally..."

# Configuration
REGISTRY=${REGISTRY:-""}  # Empty for local, or "ghcr.io/username"
TAG=${TAG:-"dev"}

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Set up Minikube Docker environment
setup_docker_env() {
    if minikube status &> /dev/null; then
        print_status "Using Minikube Docker daemon..."
        eval $(minikube docker-env)
    fi
}

# Build images
build_images() {
    print_status "Building Docker images..."
    
    # Build API Gateway
    print_status "Building api-gateway..."
    docker build -t ${REGISTRY}api-gateway:${TAG} services/api-gateway/
    
    # Build User Service
    print_status "Building user-service..."
    docker build -t ${REGISTRY}user-service:${TAG} services/user-service/
    
    # Build Order Service
    print_status "Building order-service..."
    docker build -t ${REGISTRY}order-service:${TAG} services/order-service/
    
    print_status "All images built ✓"
}

# Deploy to Kubernetes
deploy_k8s() {
    print_status "Deploying to Kubernetes..."
    
    # Apply dev overlay
    kubectl apply -k k8s/overlays/dev
    
    # Wait for deployments
    print_status "Waiting for deployments to be ready..."
    kubectl wait --for=condition=available --timeout=120s deployment/api-gateway -n microservices-demo
    kubectl wait --for=condition=available --timeout=120s deployment/user-service -n microservices-demo
    kubectl wait --for=condition=available --timeout=120s deployment/order-service -n microservices-demo
    
    print_status "Deployment complete ✓"
}

# Show status
show_status() {
    echo ""
    echo "=============================================="
    echo "Deployment Status"
    echo "=============================================="
    
    kubectl get pods -n microservices-demo
    
    echo ""
    kubectl get svc -n microservices-demo
    
    echo ""
    kubectl get ingress -n microservices-demo
}

# Port forward for local access
port_forward() {
    print_status "Setting up port forwarding..."
    
    echo ""
    echo "Services will be available at:"
    echo "  API Gateway: http://localhost:8000"
    echo "  User Service: http://localhost:8001"
    echo "  Order Service: http://localhost:8002"
    echo ""
    echo "Starting port forwards (Ctrl+C to stop)..."
    echo ""
    
    kubectl port-forward svc/api-gateway 8000:8000 -n microservices-demo &
    kubectl port-forward svc/user-service 8001:8001 -n microservices-demo &
    kubectl port-forward svc/order-service 8002:8002 -n microservices-demo &
    
    wait
}

# Usage
usage() {
    echo "Usage: $0 [command]"
    echo ""
    echo "Commands:"
    echo "  build     - Build Docker images"
    echo "  deploy    - Deploy to Kubernetes"
    echo "  all       - Build and deploy (default)"
    echo "  status    - Show deployment status"
    echo "  forward   - Set up port forwarding"
    echo ""
}

# Main
main() {
    cd "$(dirname "$0")/.."
    
    case "${1:-all}" in
        build)
            setup_docker_env
            build_images
            ;;
        deploy)
            deploy_k8s
            show_status
            ;;
        all)
            setup_docker_env
            build_images
            deploy_k8s
            show_status
            ;;
        status)
            show_status
            ;;
        forward)
            port_forward
            ;;
        *)
            usage
            exit 1
            ;;
    esac
}

main "$@"
