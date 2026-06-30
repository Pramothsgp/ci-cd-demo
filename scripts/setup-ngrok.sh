#!/bin/bash

# =============================================================================
# Ngrok Setup Script for CI/CD Demo
# =============================================================================
# This script sets up ngrok to expose your local Kubernetes services
# (ArgoCD, API Gateway) to the internet for GitHub Actions webhooks
# =============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

print_status() { echo -e "${GREEN}[INFO]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARN]${NC} $1"; }
print_error() { echo -e "${RED}[ERROR]${NC} $1"; }
print_header() { echo -e "\n${CYAN}$1${NC}"; }

# Configuration
NGROK_CONFIG_DIR="$HOME/.ngrok2"
ARGOCD_PORT=8080
API_GATEWAY_PORT=8000

print_header "=============================================="
print_header "   🌐 Ngrok Setup for CI/CD Demo"
print_header "=============================================="

# Check if ngrok is installed
check_ngrok() {
    if ! command -v ngrok &> /dev/null; then
        print_warning "ngrok is not installed. Installing..."
        
        # Install ngrok based on OS
        if [[ "$OSTYPE" == "linux-gnu"* ]]; then
            curl -s https://ngrok-agent.s3.amazonaws.com/ngrok.asc | \
                sudo tee /etc/apt/trusted.gpg.d/ngrok.asc >/dev/null && \
                echo "deb https://ngrok-agent.s3.amazonaws.com buster main" | \
                sudo tee /etc/apt/sources.list.d/ngrok.list && \
                sudo apt update && sudo apt install ngrok
        elif [[ "$OSTYPE" == "darwin"* ]]; then
            brew install ngrok/ngrok/ngrok
        else
            print_error "Please install ngrok manually from https://ngrok.com/download"
            exit 1
        fi
    fi
    
    print_status "ngrok is installed ✓"
}

# Check if ngrok is authenticated
check_ngrok_auth() {
    if [ ! -f "$HOME/.config/ngrok/ngrok.yml" ] && [ ! -f "$HOME/.ngrok2/ngrok.yml" ]; then
        print_warning "ngrok is not authenticated!"
        echo ""
        echo "Please sign up for a free ngrok account at: https://dashboard.ngrok.com/signup"
        echo "Then run: ngrok config add-authtoken YOUR_AUTH_TOKEN"
        echo ""
        read -p "Enter your ngrok auth token (or press Enter to skip): " AUTH_TOKEN
        
        if [ -n "$AUTH_TOKEN" ]; then
            ngrok config add-authtoken "$AUTH_TOKEN"
            print_status "ngrok authenticated ✓"
        else
            print_warning "Skipping ngrok authentication. Some features may not work."
        fi
    else
        print_status "ngrok is authenticated ✓"
    fi
}

# Port forward ArgoCD
setup_argocd_port_forward() {
    print_status "Setting up port forward for ArgoCD..."
    
    # Kill existing port forwards
    pkill -f "kubectl port-forward.*argocd-server" 2>/dev/null || true
    
    # Start port forward in background
    kubectl port-forward svc/argocd-server -n argocd $ARGOCD_PORT:443 &>/dev/null &
    ARGOCD_PF_PID=$!
    
    sleep 2
    
    if kill -0 $ARGOCD_PF_PID 2>/dev/null; then
        print_status "ArgoCD port forward running on localhost:$ARGOCD_PORT ✓"
        echo $ARGOCD_PF_PID > /tmp/argocd-pf.pid
    else
        print_error "Failed to start ArgoCD port forward"
        return 1
    fi
}

# Port forward API Gateway (for demo access)
setup_api_gateway_port_forward() {
    print_status "Setting up port forward for API Gateway..."
    
    # Kill existing port forwards
    pkill -f "kubectl port-forward.*api-gateway" 2>/dev/null || true
    
    # Start port forward in background
    kubectl port-forward svc/api-gateway -n microservices-demo $API_GATEWAY_PORT:8000 &>/dev/null &
    API_PF_PID=$!
    
    sleep 2
    
    if kill -0 $API_PF_PID 2>/dev/null; then
        print_status "API Gateway port forward running on localhost:$API_GATEWAY_PORT ✓"
        echo $API_PF_PID > /tmp/api-gateway-pf.pid
    else
        print_warning "API Gateway not deployed yet, skipping port forward"
    fi
}

# Start ngrok tunnels
start_ngrok_tunnels() {
    print_status "Starting ngrok tunnel for ArgoCD..."
    
    # Kill existing ngrok processes
    pkill -f "ngrok" 2>/dev/null || true
    sleep 1
    
    # Start ngrok for ArgoCD
    ngrok http $ARGOCD_PORT --log=stdout > /tmp/ngrok-argocd.log 2>&1 &
    NGROK_PID=$!
    echo $NGROK_PID > /tmp/ngrok-argocd.pid
    
    # Wait for ngrok to start
    sleep 3
    
    # Get the public URL
    NGROK_URL=$(curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4)
    
    if [ -n "$NGROK_URL" ]; then
        print_status "ngrok tunnel established ✓"
        echo ""
        echo -e "${GREEN}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${GREEN}║           🌐 NGROK TUNNEL INFORMATION                          ║${NC}"
        echo -e "${GREEN}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${GREEN}║${NC} ArgoCD Public URL:                                             ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   ${CYAN}$NGROK_URL${NC}"
        echo -e "${GREEN}║${NC}                                                                ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC} Add this to your GitHub repository:                           ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   Settings → Secrets and variables → Actions → Variables      ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   Name: ARGOCD_SERVER_URL                                      ${GREEN}║${NC}"
        echo -e "${GREEN}║${NC}   Value: ${CYAN}$NGROK_URL${NC}"
        echo -e "${GREEN}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        
        # Save URL to file
        echo "$NGROK_URL" > /tmp/ngrok-argocd-url.txt
    else
        print_error "Failed to get ngrok URL. Check /tmp/ngrok-argocd.log for details"
    fi
}

# Get ArgoCD credentials
get_argocd_credentials() {
    print_header "ArgoCD Credentials"
    
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    
    if [ -n "$ARGOCD_PASSWORD" ]; then
        echo ""
        echo -e "${BLUE}╔════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${BLUE}║           🔐 ArgoCD Login Credentials                          ║${NC}"
        echo -e "${BLUE}╠════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${BLUE}║${NC} Username: ${CYAN}admin${NC}"
        echo -e "${BLUE}║${NC} Password: ${CYAN}$ARGOCD_PASSWORD${NC}"
        echo -e "${BLUE}╚════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi
}

# Generate ArgoCD API token for GitHub Actions
generate_argocd_token() {
    print_header "Generating ArgoCD API Token for GitHub Actions"
    
    ARGOCD_PASSWORD=$(kubectl -n argocd get secret argocd-initial-admin-secret \
        -o jsonpath="{.data.password}" 2>/dev/null | base64 -d)
    
    if [ -n "$ARGOCD_PASSWORD" ]; then
        # Login to ArgoCD CLI
        if command -v argocd &> /dev/null; then
            argocd login localhost:$ARGOCD_PORT --username admin --password "$ARGOCD_PASSWORD" --insecure 2>/dev/null || true
            
            # Generate token
            TOKEN=$(argocd account generate-token --account admin 2>/dev/null)
            
            if [ -n "$TOKEN" ]; then
                echo ""
                echo -e "${YELLOW}╔════════════════════════════════════════════════════════════════╗${NC}"
                echo -e "${YELLOW}║           🔑 ArgoCD API Token for GitHub Actions               ║${NC}"
                echo -e "${YELLOW}╠════════════════════════════════════════════════════════════════╣${NC}"
                echo -e "${YELLOW}║${NC} Add this to GitHub Secrets:                                    ${YELLOW}║${NC}"
                echo -e "${YELLOW}║${NC}   Settings → Secrets and variables → Actions → Secrets        ${YELLOW}║${NC}"
                echo -e "${YELLOW}║${NC}   Name: ARGOCD_AUTH_TOKEN                                      ${YELLOW}║${NC}"
                echo -e "${YELLOW}╚════════════════════════════════════════════════════════════════╝${NC}"
                echo ""
                echo "Token (add to GitHub Secrets):"
                echo "$TOKEN"
                echo ""
                echo "$TOKEN" > /tmp/argocd-token.txt
                print_status "Token saved to /tmp/argocd-token.txt"
            fi
        else
            print_warning "ArgoCD CLI not installed. Install it for API token generation."
            echo "Install: brew install argocd  OR  curl -sSL -o argocd-linux-amd64 https://github.com/argoproj/argo-cd/releases/latest/download/argocd-linux-amd64"
        fi
    fi
}

# Show ngrok dashboard info
show_ngrok_dashboard() {
    echo ""
    print_header "📊 Ngrok Dashboard"
    echo "  Local:  http://localhost:4040"
    echo "  View tunnel status, requests, and replay webhooks"
    echo ""
}

# Cleanup function
cleanup() {
    print_header "Cleaning up..."
    
    # Kill port forwards
    [ -f /tmp/argocd-pf.pid ] && kill $(cat /tmp/argocd-pf.pid) 2>/dev/null && rm /tmp/argocd-pf.pid
    [ -f /tmp/api-gateway-pf.pid ] && kill $(cat /tmp/api-gateway-pf.pid) 2>/dev/null && rm /tmp/api-gateway-pf.pid
    
    # Kill ngrok
    [ -f /tmp/ngrok-argocd.pid ] && kill $(cat /tmp/ngrok-argocd.pid) 2>/dev/null && rm /tmp/ngrok-argocd.pid
    
    pkill -f "ngrok" 2>/dev/null || true
    pkill -f "kubectl port-forward.*argocd-server" 2>/dev/null || true
    
    print_status "Cleanup complete ✓"
}

# Main execution
main() {
    case "${1:-start}" in
        start)
            check_ngrok
            check_ngrok_auth
            setup_argocd_port_forward
            setup_api_gateway_port_forward
            start_ngrok_tunnels
            get_argocd_credentials
            generate_argocd_token
            show_ngrok_dashboard
            
            echo ""
            print_status "Setup complete! Keep this terminal open to maintain the tunnels."
            echo ""
            echo "Press Ctrl+C to stop all tunnels and port forwards"
            
            # Wait for interrupt
            trap cleanup EXIT
            wait
            ;;
        stop)
            cleanup
            ;;
        url)
            if [ -f /tmp/ngrok-argocd-url.txt ]; then
                cat /tmp/ngrok-argocd-url.txt
            else
                # Try to get from ngrok API
                curl -s http://localhost:4040/api/tunnels | grep -o '"public_url":"https://[^"]*' | head -1 | cut -d'"' -f4
            fi
            ;;
        *)
            echo "Usage: $0 {start|stop|url}"
            exit 1
            ;;
    esac
}

main "$@"
