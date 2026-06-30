# CI/CD Demo with Docker, Kubernetes, GitHub Actions, and Argo CD

A comprehensive demonstration of a microservices architecture with a complete CI/CD pipeline using modern DevOps practices. **Push code → Auto-build → Auto-deploy** to your local Kubernetes cluster!

## 🚀 Pipeline Overview

```
┌──────────────┐     ┌──────────────┐     ┌──────────────┐     ┌──────────────┐
│   Git Push   │────▶│GitHub Actions│────▶│  Docker Hub  │────▶│    ArgoCD    │
│   (main)     │     │  (Build/Test)│     │  (Registry)  │     │   (GitOps)   │
└──────────────┘     └──────────────┘     └──────────────┘     └──────┬───────┘
                                                                       │
                                                                       ▼
                                                              ┌──────────────┐
                                                              │  Kubernetes  │
                                                              │   (Local)    │
                                                              └──────────────┘
```

**What happens when you push code:**
1. **GitHub Actions** detects the push to `main` branch
2. **Runs tests** for all microservices
3. **Builds Docker images** with git SHA tags
4. **Pushes to Docker Hub** (public registry)
5. **Updates K8s manifests** with new image tags
6. **ArgoCD detects changes** and syncs to your local cluster
7. **Kubernetes** pulls new images and restarts pods

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                              NGINX Ingress                                   │
│                         (Load Balancing + Routing)                           │
└──────────────────────────────┬──────────────────────────────────────────────┘
                               │
              ┌────────────────┼────────────────┐
              │                │                │
              ▼                ▼                ▼
       ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
       │  API Gateway │ │ User Service │ │Order Service │
       │    :8000     │ │    :8001     │ │    :8002     │
       │   (FastAPI)  │ │  (FastAPI)   │ │  (FastAPI)   │
       └──────────────┘ └──────────────┘ └──────┬───────┘
                                                │
                                    (validates users)
                                                │
                                    ┌───────────▼───────────┐
                                    │    User Service       │
                                    └───────────────────────┘
```

## 🛠️ Technology Stack

| Component | Technology |
|-----------|------------|
| **Language** | Python 3.11 + FastAPI |
| **Containerization** | Docker (multi-stage builds) |
| **Orchestration** | Kubernetes (Minikube for local) |
| **CI** | GitHub Actions |
| **CD** | Argo CD (GitOps) |
| **Load Balancing** | NGINX Ingress Controller |
| **Monitoring** | Prometheus + Grafana |
| **Config Management** | Kustomize |
| **Tunnel** | Ngrok (connect GitHub to local) |

## 📁 Project Structure

```
ci-cd/
├── .github/workflows/           # GitHub Actions CI/CD
│   └── ci-cd.yaml               # Main pipeline
├── services/                    # Microservices
│   ├── api-gateway/             # Entry point service
│   ├── user-service/            # User management
│   └── order-service/           # Order management
├── k8s/                         # Kubernetes manifests
│   ├── base/                    # Base configurations
│   └── overlays/                # Environment-specific configs
│       ├── dev/
│       └── prod/
├── argocd/                      # Argo CD configurations
│   └── applications/
├── monitoring/                  # Prometheus & Grafana
│   ├── prometheus/
│   └── grafana/
├── .github/workflows/           # CI/CD pipelines
│   ├── ci.yaml
│   └── cd.yaml
├── scripts/                     # Setup scripts
├── docker-compose.yaml          # Local development
└── docker-compose.dev.yaml      # Dev with hot-reload
```

## 🚀 Quick Start

### Prerequisites

- Docker & Docker Compose
- Minikube
- kubectl
- Git

### Option 1: Local Development with Docker Compose

```bash
# Clone the repository
git clone <your-repo-url>
cd ci-cd

# Start all services
docker-compose up --build

# Access the services
curl http://localhost:8000/health           # API Gateway
curl http://localhost:8000/api/users        # Get users
curl http://localhost:8000/api/orders       # Get orders
curl http://localhost:8000/api/dashboard    # Dashboard
```

### Option 2: Kubernetes with Minikube

```bash
# 1. Setup Minikube
chmod +x scripts/*.sh
./scripts/setup-minikube.sh

# 2. Setup NGINX Ingress
./scripts/setup-ingress.sh

# 3. Build and deploy services
./scripts/build-deploy.sh all

# 4. Add hosts entries (shown by setup script)
sudo nano /etc/hosts
# Add: <minikube-ip> demo.local users.demo.local orders.demo.local

# 5. Access services
curl http://demo.local/api/users
curl http://demo.local/api/orders
```

### Option 3: Full CI/CD with Argo CD

```bash
# 1. Complete steps 1-4 from Option 2

# 2. Setup Argo CD
./scripts/setup-argocd.sh

# 3. Access Argo CD UI
kubectl port-forward svc/argocd-server -n argocd 8080:443
# Open: https://localhost:8080

# 4. Connect your GitHub repository in Argo CD

# 5. Apply Argo CD applications
kubectl apply -f argocd/applications/
```

## 📡 API Endpoints

### API Gateway (http://localhost:8000 or http://demo.local)

| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/ready` | Readiness check |
| GET | `/api/dashboard` | Aggregated dashboard |
| GET | `/api/users` | List all users |
| GET | `/api/users/{id}` | Get user by ID |
| POST | `/api/users` | Create user |
| PUT | `/api/users/{id}` | Update user |
| DELETE | `/api/users/{id}` | Delete user |
| GET | `/api/orders` | List all orders |
| GET | `/api/orders/{id}` | Get order by ID |
| POST | `/api/orders` | Create order |
| PUT | `/api/orders/{id}/status` | Update order status |

### Example Requests

```bash
# Create a user
curl -X POST http://localhost:8000/api/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John Doe", "email": "john@example.com", "role": "user"}'

# Create an order
curl -X POST http://localhost:8000/api/orders \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "items": [
      {"product_name": "Laptop", "quantity": 1, "unit_price": 999.99}
    ],
    "shipping_address": "123 Main St"
  }'

# Get dashboard
curl http://localhost:8000/api/dashboard
```

## 🔄 CI/CD Pipeline

### Continuous Integration (GitHub Actions)

1. **Trigger**: Push to `main`/`develop` or PR to `main`
2. **Detect Changes**: Only build modified services
3. **Test**: Run pytest for each service
4. **Lint**: Check code with ruff
5. **Build**: Multi-stage Docker build
6. **Push**: Push to GitHub Container Registry (GHCR)

### Continuous Deployment (Argo CD)

1. **CD Workflow**: Updates image tags in K8s manifests
2. **Git Commit**: Changes pushed to repository
3. **Argo CD Sync**: Detects changes and deploys automatically
4. **Health Checks**: Verifies deployment success

```
┌──────────┐    ┌──────────┐    ┌──────────┐    ┌──────────┐
│  Push    │───▶│   CI     │───▶│  Update  │───▶│ Argo CD  │
│  Code    │    │ Pipeline │    │ Manifests│    │  Sync    │
└──────────┘    └──────────┘    └──────────┘    └──────────┘
```

## ⚖️ Load Balancing

NGINX Ingress Controller provides:

- **Round-robin** load balancing across pod replicas
- **Path-based routing** to different services
- **Health checks** for backend pods
- **Rate limiting** (configurable)
- **CORS** support

Configuration in `k8s/base/ingress.yaml`

## 📊 Monitoring

### Setup Monitoring

```bash
./scripts/setup-monitoring.sh
```

### Access

```bash
# Prometheus (metrics)
kubectl port-forward svc/prometheus 9090:9090 -n monitoring
# Open: http://localhost:9090

# Grafana (dashboards)
kubectl port-forward svc/grafana 3000:3000 -n monitoring
# Open: http://localhost:3000
# User: admin / Password: admin123
```

## 🔧 Configuration

### Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `USER_SERVICE_URL` | `http://user-service:8001` | User service URL |
| `ORDER_SERVICE_URL` | `http://order-service:8002` | Order service URL |
| `LOG_LEVEL` | `INFO` | Logging level |

### Kustomize Overlays

- **dev**: 1 replica, minimal resources, debug logging
- **prod**: 3 replicas, higher resources, info logging

```bash
# Deploy to dev
kubectl apply -k k8s/overlays/dev

# Deploy to prod
kubectl apply -k k8s/overlays/prod
```

## 🧪 Testing

```bash
# Run tests for all services
cd services/api-gateway && pytest tests/ -v
cd services/user-service && pytest tests/ -v
cd services/order-service && pytest tests/ -v
```

## 📝 Demo Walkthrough

### 1. Show Microservices Architecture
- Explain the 3-service architecture
- Show inter-service communication (order-service → user-service)

### 2. Demonstrate Local Development
```bash
docker-compose up
curl http://localhost:8000/api/dashboard
```

### 3. Show Kubernetes Deployment
```bash
kubectl get pods -n microservices-demo
kubectl get svc -n microservices-demo
```

### 4. Demonstrate Load Balancing
```bash
# Scale up
kubectl scale deployment api-gateway --replicas=3 -n microservices-demo

# Watch load distribution
for i in {1..10}; do curl -s http://demo.local/health | jq .service; done
```

### 5. Trigger CI/CD Pipeline
```bash
# Make a code change
git add . && git commit -m "Update service"
git push

# Watch GitHub Actions
# Watch Argo CD sync
```

### 6. Show Monitoring
- Open Grafana dashboard
- Show service metrics

## 🛡️ Security Notes

This is a **demo project**. For production:

- [ ] Use proper secrets management (Vault, AWS Secrets Manager)
- [ ] Enable TLS/HTTPS
- [ ] Implement authentication/authorization
- [ ] Add network policies
- [ ] Use non-root containers (already implemented)
- [ ] Scan images for vulnerabilities

## 📚 Resources

- [FastAPI Documentation](https://fastapi.tiangolo.com/)
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Argo CD Documentation](https://argo-cd.readthedocs.io/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [NGINX Ingress Controller](https://kubernetes.github.io/ingress-nginx/)

---

## 🎯 Complete CI/CD Demo with Ngrok

This section explains how to demo the **full CI/CD pipeline** with code changes automatically deploying to your local Kubernetes cluster.

### Prerequisites

1. **Docker Hub Account** - [Sign up](https://hub.docker.com/signup)
2. **GitHub Account** - [Sign up](https://github.com/signup)
3. **Ngrok Account** - [Sign up (free)](https://dashboard.ngrok.com/signup)

### Step 1: Complete Local Setup

```bash
# Run the complete setup script
chmod +x scripts/setup-complete-demo.sh
./scripts/setup-complete-demo.sh full
```

This will:
- ✅ Start Minikube
- ✅ Install ArgoCD
- ✅ Install ArgoCD Image Updater
- ✅ Build and push Docker images
- ✅ Deploy all services
- ✅ Configure ArgoCD application

### Step 2: Configure GitHub Repository

1. **Create a new GitHub repository** or use existing

2. **Add Repository Secrets** (Settings → Secrets and variables → Actions → Secrets):
   
   | Secret Name | Value |
   |-------------|-------|
   | `DOCKER_HUB_USERNAME` | Your Docker Hub username |
   | `DOCKER_HUB_TOKEN` | Your Docker Hub access token |
   | `ARGOCD_AUTH_TOKEN` | Token from ngrok setup (optional) |

3. **Create Docker Hub Access Token:**
   - Go to [Docker Hub Security Settings](https://hub.docker.com/settings/security)
   - Click "New Access Token"
   - Copy the token and add it as `DOCKER_HUB_TOKEN` secret

### Step 3: Start Ngrok Tunnel

```bash
# Start ngrok tunnel (keep this terminal open!)
./scripts/setup-ngrok.sh start
```

This will display:
- 🌐 **Ngrok public URL** for ArgoCD
- 🔐 **ArgoCD credentials**
- 🔑 **ArgoCD API token** for GitHub Actions

**Add the ngrok URL to GitHub:**
- Settings → Secrets and variables → Actions → **Variables**
- Name: `ARGOCD_SERVER_URL`
- Value: `https://xxxx-xx-xxx-xxx-xxx.ngrok-free.app`

### Step 4: Push Code to GitHub

```bash
# Initialize git and push
git init
git add .
git commit -m "Initial commit"
git branch -M main
git remote add origin https://github.com/YOUR_USERNAME/YOUR_REPO.git
git push -u origin main
```

### Step 5: Demo the Pipeline! 🎉

**Make a code change:**
```bash
# Edit any service (e.g., add a new endpoint)
echo "" >> services/api-gateway/app/main.py
echo "# Demo change - $(date)" >> services/api-gateway/app/main.py
```

**Commit and push:**
```bash
git add .
git commit -m "🚀 Demo: trigger CI/CD pipeline"
git push
```

**Watch the magic happen:**

| What to Watch | Where |
|---------------|-------|
| **GitHub Actions** | `https://github.com/YOUR_USER/YOUR_REPO/actions` |
| **ArgoCD Dashboard** | `http://localhost:8080` or ngrok URL |
| **Kubernetes Pods** | `kubectl get pods -n microservices-demo -w` |

### Pipeline Flow Visualization

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                           YOU PUSH CODE TO MAIN                              │
└─────────────────────────────────┬───────────────────────────────────────────┘
                                  │
                                  ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  GITHUB ACTIONS                                                              │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  ┌──────────────────┐ │
│  │ Detect       │→ │ Run Tests    │→ │ Build Images │→ │ Push to Docker   │ │
│  │ Changes      │  │ (pytest)     │  │ (3 services) │  │ Hub              │ │
│  └──────────────┘  └──────────────┘  └──────────────┘  └────────┬─────────┘ │
└────────────────────────────────────────────────────────────────────────────┘
                                                                   │
                                                                   ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  GITHUB ACTIONS - UPDATE MANIFESTS                                           │
│  ┌───────────────────────────────────────────────────────────────────────┐  │
│  │  kustomize edit set image pramothsgp/api-gateway:abc123               │  │
│  │  git commit -m "Update image tags" && git push                        │  │
│  └───────────────────────────────────────────────────────────────────────┘  │
└─────────────────────────────────────────┬───────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  ARGOCD (via ngrok tunnel)                                                   │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────────────────┐  │
│  │ Detect Git   │→ │ Compare      │→ │ Sync to Kubernetes               │  │
│  │ Changes      │  │ Desired vs   │  │ (Pull new images, restart pods)  │  │
│  │              │  │ Actual State │  │                                  │  │
│  └──────────────┘  └──────────────┘  └──────────────────────────────────┘  │
└─────────────────────────────────────────────────────────────────────────────┘
                                          │
                                          ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│  YOUR LOCAL KUBERNETES (Minikube)                                            │
│  ┌────────────────────────────────────────────────────────────────────────┐ │
│  │  microservices-demo namespace                                          │ │
│  │  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐                    │ │
│  │  │ api-gateway │  │user-service │  │order-service│  ← NEW IMAGES!     │ │
│  │  │   :abc123   │  │   :abc123   │  │   :abc123   │                    │ │
│  │  └─────────────┘  └─────────────┘  └─────────────┘                    │ │
│  └────────────────────────────────────────────────────────────────────────┘ │
└─────────────────────────────────────────────────────────────────────────────┘
```

### Useful Demo Commands

```bash
# Watch pods updating in real-time
kubectl get pods -n microservices-demo -w

# Check current images
kubectl get pods -n microservices-demo -o jsonpath='{range .items[*]}{.spec.containers[*].image}{"\n"}{end}'

# View ArgoCD app status
kubectl get application -n argocd

# Port-forward to test the API
kubectl port-forward svc/api-gateway -n microservices-demo 8000:8000
curl http://localhost:8000/health

# Check GitHub Actions logs
# Visit: https://github.com/YOUR_USER/YOUR_REPO/actions

# View ngrok traffic (useful for debugging)
# Visit: http://localhost:4040
```

### Troubleshooting

| Issue | Solution |
|-------|----------|
| GitHub Actions fails | Check secrets are set correctly |
| Docker push fails | Verify `DOCKER_HUB_TOKEN` has write access |
| ArgoCD not syncing | Check ngrok tunnel is running |
| Pods not updating | Run `kubectl rollout restart deployment -n microservices-demo` |
| Ngrok URL changed | Update `ARGOCD_SERVER_URL` variable in GitHub |

### Cleanup

```bash
# Stop ngrok and port-forwards
./scripts/setup-ngrok.sh stop

# Delete all resources
kubectl delete -k k8s/overlays/dev
kubectl delete -f argocd/applications/

# Stop minikube
minikube stop

# Or delete everything
minikube delete
```

---

## 📄 License

MIT License - Feel free to use for learning and demonstrations.
