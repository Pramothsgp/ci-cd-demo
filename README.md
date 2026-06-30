# CI/CD Demo with Docker, Kubernetes, GitHub Actions, and Argo CD

A comprehensive demonstration of a microservices architecture with a complete CI/CD pipeline using modern DevOps practices.

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

## 📁 Project Structure

```
ci-cd/
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

## 📄 License

MIT License - Feel free to use for learning and demonstrations.
