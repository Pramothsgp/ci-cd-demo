#!/bin/bash

# =============================================================================
# Complete CI/CD Demo Setup Script
# =============================================================================
# This script sets up the entire CI/CD pipeline locally:
# 1. Minikube with Kubernetes
# 2. ArgoCD for GitOps deployments
# 3. Ngrok for GitHub Actions connectivity
# 4. All microservices deployed
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m'
BOLD='\033[1m'

print_status() { echo -e "${GREEN}[✓]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[!]${NC} $1"; }
print_error() { echo -e "${RED}[✗]${NC} $1"; }
print_info() { echo -e "${BLUE}[i]${NC} $1"; }
print_step() { echo -e "\n${MAGENTA}${BOLD}=== $1 ===${NC}"; }

# Configuration
DOCKER_HUB_USERNAME="${DOCKER_HUB_USERNAME:-pramothsgp}"
GITHUB_REPO="${GITHUB_REPO:-YOUR_GITHUB_USERNAME/ci-cd-demo}"
MINIKUBE_MEMORY="${MINIKUBE_MEMORY:-4096}"
MINIKUBE_CPUS="${MINIKUBE_CPUS:-2}"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# =============================================================================
# Pre-flight Checks
# =============================================================================
preflight_checks() {
    print_step "Pre-flight Checks"
    
    local missing_tools=()
    
    # Check required tools
    for tool in docker kubectl minikube; do
        if ! command -v $tool &> /dev/null; then
            missing_tools+=("$tool")
        else
            print_status "$tool is installed"
        fi
    done
    
    # Optional tools
    for tool in ngrok argocd kustomize; do
        if command -v $tool &> /dev/null; then
            print_status "$tool is installed"
        else
            print_warning "$tool is not installed (optional, will install if needed)"
        fi
    done
    
    if [ ${#missing_tools[@]} -ne 0 ]; then
        print_error "Missing required tools: ${missing_tools[*]}"
        echo ""
        echo "Install them using:"
        echo "  Docker: https://docs.docker.com/get-docker/"
        echo "  kubectl: curl -LO \"https://dl.k8s.io/release/\$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl\""
        echo "  minikube: curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64"
        exit 1
    fi
    
    # Check Docker is running
    if ! docker info &> /dev/null; then
        print_error "Docker is not running. Please start Docker first."
        exit 1
    fi
    print_status "Docker is running"
}

# =============================================================================
# Start Minikube
# =============================================================================
start_minikube() {
    print_step "Starting Minikube Cluster"
    
    # Check if minikube is already running
    if minikube status &> /dev/null; then
        print_status "Minikube is already running"
    else
        print_info "Starting Minikube with ${MINIKUBE_MEMORY}MB RAM and ${MINIKUBE_CPUS} CPUs..."
        minikube start \
            --memory=$MINIKUBE_MEMORY \
            --cpus=$MINIKUBE_CPUS \
            --driver=docker \
            --addons=ingress \
            --addons=metrics-server
        print_status "Minikube started successfully"
    fi
    
    # Configure kubectl context
    kubectl config use-context minikube
    print_status "kubectl configured for minikube"
}

# =============================================================================
# Install ArgoCD
# =============================================================================
install_argocd() {
    print_step "Installing ArgoCD"
    
    # Create namespace
    kubectl create namespace argocd --dry-run=client -o yaml | kubectl apply -f -
    
    # Install ArgoCD (use --server-side to avoid annotation size limit on large CRDs)
    print_info "Applying ArgoCD manifests..."
    kubectl apply -n argocd --server-side \
        -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
    
    # Wait for ArgoCD to be ready
    print_info "Waiting for ArgoCD pods to be ready..."
    kubectl wait --for=condition=available --timeout=300s \
        deployment/argocd-server -n argocd
    
    print_status "ArgoCD installed successfully"
    
    # Get admin password
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" | base64 -d)
    
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║              ArgoCD Credentials                              ║${NC}"
    echo -e "${CYAN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${CYAN}║${NC} Username: ${GREEN}admin${NC}"
    echo -e "${CYAN}║${NC} Password: ${GREEN}$ARGOCD_PASSWORD${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# =============================================================================
# Install ArgoCD Image Updater (Optional - for automatic image updates)
# =============================================================================
install_argocd_image_updater() {
    print_step "Installing ArgoCD Image Updater"
    
    kubectl apply -n argocd \
        -f https://raw.githubusercontent.com/argoproj-labs/argocd-image-updater/stable/manifests/install.yaml
    
    # Apply custom config
    if [ -f "$PROJECT_DIR/argocd/image-updater/config.yaml" ]; then
        kubectl apply -f "$PROJECT_DIR/argocd/image-updater/config.yaml"
    fi
    
    print_status "ArgoCD Image Updater installed"
}

# =============================================================================
# Build and Push Docker Images
# =============================================================================
build_and_push_images() {
    print_step "Building and Pushing Docker Images"
    
    # Check if logged in to Docker Hub
    if ! docker info 2>/dev/null | grep -q "Username"; then
        print_warning "Please log in to Docker Hub"
        docker login
    fi
    
    cd "$PROJECT_DIR"
    
    for service in api-gateway user-service order-service; do
        print_info "Building $service..."
        docker build -t "$DOCKER_HUB_USERNAME/$service:latest" "services/$service"
        
        print_info "Pushing $service to Docker Hub..."
        docker push "$DOCKER_HUB_USERNAME/$service:latest"
        
        print_status "$service built and pushed"
    done
}

# =============================================================================
# Create Kubernetes Namespace and Resources
# =============================================================================
deploy_base_resources() {
    print_step "Deploying Base Kubernetes Resources"
    
    cd "$PROJECT_DIR"
    
    # Create namespace
    kubectl apply -f k8s/base/namespace.yaml
    
    # Apply kustomization
    kubectl apply -k k8s/overlays/dev
    
    print_status "Base resources deployed"
}

# =============================================================================
# Configure ArgoCD Application
# =============================================================================
configure_argocd_app() {
    print_step "Configuring ArgoCD Application"
    
    cd "$PROJECT_DIR"
    
    # Update the repo URL in the ArgoCD application
    if [ "$GITHUB_REPO" != "YOUR_GITHUB_USERNAME/ci-cd-demo" ]; then
        sed -i "s|YOUR_GITHUB_USERNAME/ci-cd-demo|$GITHUB_REPO|g" \
            argocd/applications/microservices-app.yaml
    fi
    
    # Apply ArgoCD application
    kubectl apply -f argocd/applications/project.yaml
    kubectl apply -f argocd/applications/microservices-app.yaml
    
    print_status "ArgoCD application configured"
}

# =============================================================================
# Setup Ngrok for GitHub Actions
# =============================================================================
setup_ngrok() {
    print_step "Setting up Ngrok for GitHub Actions"
    
    cd "$PROJECT_DIR"
    
    # Make ngrok script executable
    chmod +x scripts/setup-ngrok.sh
    
    print_info "To start ngrok tunnel for GitHub Actions connectivity:"
    echo ""
    echo "  ./scripts/setup-ngrok.sh start"
    echo ""
    print_info "This will:"
    echo "  1. Port-forward ArgoCD to localhost:8080"
    echo "  2. Create ngrok tunnel"
    echo "  3. Display the public URL to add to GitHub"
    echo ""
}

# =============================================================================
# Display GitHub Setup Instructions
# =============================================================================
display_github_instructions() {
    print_step "GitHub Repository Setup"
    
    echo ""
    echo -e "${YELLOW}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${YELLOW}║          GitHub Repository Configuration                     ║${NC}"
    echo -e "${YELLOW}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${YELLOW}║${NC}                                                              ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${BOLD}1. Create GitHub Repository${NC}                                 ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}    Go to: https://github.com/new                             ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                              ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${BOLD}2. Add Repository Secrets${NC} (Settings → Secrets → Actions)    ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}    • DOCKER_HUB_USERNAME: $DOCKER_HUB_USERNAME               ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}    • DOCKER_HUB_TOKEN: (your Docker Hub access token)        ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}    • ARGOCD_AUTH_TOKEN: (from setup-ngrok.sh output)         ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                              ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${BOLD}3. Add Repository Variables${NC} (Settings → Variables → Actions)${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}    • ARGOCD_SERVER_URL: (ngrok URL from setup-ngrok.sh)      ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                              ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC} ${BOLD}4. Push Code to GitHub${NC}                                      ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}    git remote add origin https://github.com/USER/REPO.git   ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}    git push -u origin main                                   ${YELLOW}║${NC}"
    echo -e "${YELLOW}║${NC}                                                              ${YELLOW}║${NC}"
    echo -e "${YELLOW}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

# =============================================================================
# Display Demo Instructions
# =============================================================================
display_demo_instructions() {
    print_step "CI/CD Demo Instructions"
    
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║              🎉 Setup Complete!                              ║${NC}"
    echo -e "${GREEN}╠══════════════════════════════════════════════════════════════╣${NC}"
    echo -e "${GREEN}║${NC}                                                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC} ${BOLD}To demonstrate the CI/CD pipeline:${NC}                         ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}Step 1:${NC} Start ngrok tunnel (keep terminal open)            ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}         ${MAGENTA}./scripts/setup-ngrok.sh start${NC}                      ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}Step 2:${NC} Make a code change in services/                    ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}         ${MAGENTA}echo '# test' >> services/api-gateway/app/main.py${NC}  ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}Step 3:${NC} Commit and push                                    ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}         ${MAGENTA}git add . && git commit -m \"Update\" && git push${NC}    ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC} ${CYAN}Step 4:${NC} Watch the pipeline                                 ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}         • GitHub Actions: github.com/USER/REPO/actions       ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}         • ArgoCD: localhost:8080 (or ngrok URL)              ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}         • Kubernetes: kubectl get pods -n microservices-demo ${GREEN}║${NC}"
    echo -e "${GREEN}║${NC}                                                              ${GREEN}║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    echo -e "${BLUE}Useful Commands:${NC}"
    echo "  kubectl get pods -n microservices-demo     # Check pod status"
    echo "  kubectl get svc -n microservices-demo      # Check services"
    echo "  kubectl logs -f -l app=api-gateway -n microservices-demo  # View logs"
    echo "  minikube dashboard                         # Open K8s dashboard"
    echo "  ./scripts/setup-ngrok.sh url               # Get ngrok URL"
    echo ""
}

# =============================================================================
# Main Execution
# =============================================================================
main() {
    echo ""
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}║   ${BOLD}🚀 CI/CD Demo - Complete Setup${NC}${CYAN}                             ║${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}║   GitHub Actions → Docker Hub → ArgoCD → Kubernetes          ║${NC}"
    echo -e "${CYAN}║                                                              ║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════╝${NC}"
    echo ""
    
    case "${1:-full}" in
        full)
            preflight_checks
            start_minikube
            install_argocd
            install_argocd_image_updater
            build_and_push_images
            deploy_base_resources
            configure_argocd_app
            setup_ngrok
            display_github_instructions
            display_demo_instructions
            ;;
        minikube)
            preflight_checks
            start_minikube
            ;;
        argocd)
            install_argocd
            install_argocd_image_updater
            ;;
        build)
            build_and_push_images
            ;;
        deploy)
            deploy_base_resources
            configure_argocd_app
            ;;
        ngrok)
            setup_ngrok
            ;;
        help)
            echo "Usage: $0 {full|minikube|argocd|build|deploy|ngrok|help}"
            echo ""
            echo "Commands:"
            echo "  full     - Run complete setup (default)"
            echo "  minikube - Start Minikube only"
            echo "  argocd   - Install ArgoCD only"
            echo "  build    - Build and push Docker images"
            echo "  deploy   - Deploy to Kubernetes"
            echo "  ngrok    - Show ngrok setup instructions"
            echo "  help     - Show this help message"
            ;;
        *)
            print_error "Unknown command: $1"
            echo "Run '$0 help' for usage"
            exit 1
            ;;
    esac
}

main "$@"
