# CI/CD Pipeline Explained - Simple Guide

This guide explains how the entire CI/CD (Continuous Integration / Continuous Deployment) pipeline works in this demo project. Written in plain English for beginners.

---

## What is CI/CD?

**CI (Continuous Integration)** = Automatically test and build your code when you push changes  
**CD (Continuous Deployment)** = Automatically deploy your code to servers after it passes tests

Think of it like a factory assembly line:
```
You write code → Robot checks it → Robot packages it → Robot delivers it
```

---

## The Big Picture

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                         YOUR CI/CD PIPELINE                                  │
└─────────────────────────────────────────────────────────────────────────────┘

    YOU                    GITHUB                   DOCKER HUB              YOUR COMPUTER
     │                        │                         │                        │
     │  1. Push code          │                         │                        │
     │ ──────────────────────>│                         │                        │
     │                        │                         │                        │
     │                        │  2. Run tests           │                        │
     │                        │  3. Build Docker images │                        │
     │                        │ ──────────────────────> │                        │
     │                        │                         │  4. Store images       │
     │                        │                         │                        │
     │                        │                         │  5. ArgoCD pulls       │
     │                        │                         │ ──────────────────────>│
     │                        │                         │                        │
     │  6. App is live!       │                         │                        │
     │ <──────────────────────────────────────────────────────────────────────  │
```

---

## The 3 Microservices

This project has 3 small applications (microservices) that work together:

| Service | What it does | Port |
|---------|--------------|------|
| **API Gateway** | Front door - receives all requests and routes them | 8000 |
| **User Service** | Manages users (create, read, update, delete) | 8001 |
| **Order Service** | Manages orders (create, list, update status) | 8002 |

### How they talk to each other:

```
Internet Request
       │
       ▼
┌──────────────┐
│ API Gateway  │  ← Entry point (port 8000)
│   /users/*   │
│   /orders/*  │
└──────┬───────┘
       │
       ├────────────────┬────────────────┐
       │                │                │
       ▼                ▼                ▼
┌──────────────┐ ┌──────────────┐ ┌──────────────┐
│ User Service │ │Order Service │ │Order Service │
│  GET /users  │ │ GET /orders  │ │checks if user│
└──────────────┘ └──────────────┘ │   exists     │
                                  └──────────────┘
```

---

## Step-by-Step: What Happens When You Push Code

### Step 1: You Push Code to GitHub
```bash
git add .
git commit -m "Fixed a bug"
git push origin main
```

### Step 2: GitHub Actions Wakes Up
- GitHub sees: "Oh, someone pushed to main branch!"
- It reads `.github/workflows/ci-cd.yaml` file
- Starts running the pipeline automatically

### Step 3: Tests Run
```
GitHub Actions runs:
├── Install Python
├── Install dependencies (pip install)
└── Run tests (pytest)
    ├── ✅ api-gateway tests passed
    ├── ✅ user-service tests passed
    └── ✅ order-service tests passed
```

### Step 4: Docker Images Are Built
Think of Docker images like "shipping containers" for your app:
```
Your Python code + Dependencies + Config = Docker Image
```

GitHub Actions:
1. Builds an image for api-gateway
2. Builds an image for user-service  
3. Builds an image for order-service
4. Tags them with the git commit SHA (like a version number)

### Step 5: Images Pushed to Docker Hub
Docker Hub is like a warehouse for Docker images:
```
pramothsgp/api-gateway:abc123    ← Stored here
pramothsgp/user-service:abc123   ← Stored here
pramothsgp/order-service:abc123  ← Stored here
```

### Step 6: ArgoCD Detects New Images
ArgoCD is watching Docker Hub. It sees:
> "Hey! There's a new version of api-gateway (abc123). Let me deploy it!"

### Step 7: Kubernetes Pulls and Deploys
Kubernetes:
1. Pulls the new images from Docker Hub
2. Stops the old containers
3. Starts new containers with the new code
4. Routes traffic to the new containers

**Your new code is now live! 🎉**

---

## The Tools Explained

### Docker
**What**: Packages your app into a container  
**Why**: "Works on my machine" problem solved - same container runs everywhere

```
Before Docker:
  - "It works on my laptop!"
  - "But it doesn't work on the server..."

After Docker:
  - Same container runs on laptop, server, cloud, anywhere
```

### Kubernetes (K8s)
**What**: Manages your containers  
**Why**: Automatically restarts crashed apps, scales when needed, load balances

Think of it as a really smart container manager:
```
Kubernetes can:
├── Restart crashed containers automatically
├── Run multiple copies for high traffic
├── Distribute traffic evenly (load balancing)
└── Roll back if something goes wrong
```

### GitHub Actions
**What**: Runs scripts when you push code  
**Why**: Automates testing and building

```yaml
# .github/workflows/ci-cd.yaml
on:
  push:
    branches: [main]  # Trigger when pushing to main

jobs:
  test:     # First, run tests
  build:    # Then, build images
  push:     # Finally, push to Docker Hub
```

### ArgoCD
**What**: Continuously syncs your Kubernetes cluster with your Git repo  
**Why**: GitOps - your Git repo is the "source of truth"

```
Git Repo (what you want) ←──── ArgoCD compares ────→ Cluster (what you have)
                                    │
                                    ▼
                          Makes them match!
```

### Docker Compose
**What**: Runs multiple containers locally for development  
**Why**: Easy local testing without Kubernetes

```bash
docker-compose up    # Start all services locally
docker-compose down  # Stop everything
```

---

## Project Files Explained

```
ci-cd/
│
├── services/                    # Your actual code
│   ├── api-gateway/
│   │   ├── app/main.py         # FastAPI application
│   │   ├── Dockerfile          # How to build the container
│   │   └── requirements.txt    # Python dependencies
│   ├── user-service/
│   └── order-service/
│
├── k8s/                         # Kubernetes configs
│   ├── base/                    # Common settings
│   │   ├── deployment.yaml     # How to run containers
│   │   ├── service.yaml        # Network settings
│   │   └── configmap.yaml      # Environment variables
│   └── overlays/
│       ├── dev/                 # Development settings
│       └── prod/                # Production settings
│
├── .github/workflows/           # CI/CD pipelines
│   └── ci-cd.yaml              # Main pipeline definition
│
├── argocd/                      # ArgoCD configs
│   └── applications/
│       └── microservices-app.yaml  # What to deploy
│
├── docker-compose.yaml          # Local development
└── scripts/                     # Helper scripts
```

---

## Common Commands

### Running Locally (without Kubernetes)
```bash
# Start all services
docker-compose up -d

# See running services
docker ps

# View logs
docker-compose logs -f

# Stop everything
docker-compose down
```

### Checking Kubernetes
```bash
# See all running pods
kubectl get pods -n microservices-demo

# See services
kubectl get svc -n microservices-demo

# View pod logs
kubectl logs -f <pod-name> -n microservices-demo

# Restart a deployment
kubectl rollout restart deployment/api-gateway -n microservices-demo
```

### Checking ArgoCD
```bash
# Port forward to access UI
kubectl port-forward svc/argocd-server -n argocd 8080:443

# Open https://localhost:8080 in browser
```

---

## API Endpoints

### API Gateway (port 8000)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/users` | List all users |
| GET | `/users/{id}` | Get specific user |
| POST | `/users` | Create user |
| GET | `/orders` | List all orders |
| POST | `/orders` | Create order |

### User Service (port 8001)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/users` | List users |
| POST | `/users` | Create user |
| GET | `/users/{id}` | Get user |
| PUT | `/users/{id}` | Update user |
| DELETE | `/users/{id}` | Delete user |

### Order Service (port 8002)
| Method | Endpoint | Description |
|--------|----------|-------------|
| GET | `/health` | Health check |
| GET | `/orders` | List orders |
| POST | `/orders` | Create order |
| GET | `/orders/{id}` | Get order |
| PUT | `/orders/{id}/status` | Update status |

---

## Testing the APIs

```bash
# Health check
curl http://localhost:8000/health

# Get all users
curl http://localhost:8000/users

# Create a user
curl -X POST http://localhost:8000/users \
  -H "Content-Type: application/json" \
  -d '{"name": "John", "email": "john@example.com"}'

# Get all orders
curl http://localhost:8000/orders

# Create an order
curl -X POST http://localhost:8000/orders \
  -H "Content-Type: application/json" \
  -d '{
    "user_id": 1,
    "items": [{"product_name": "Laptop", "quantity": 1, "unit_price": 999.99}],
    "shipping_address": "123 Main St"
  }'
```

---

## Troubleshooting

### "Services won't start"
```bash
# Check if ports are in use
lsof -i :8000
lsof -i :8001
lsof -i :8002

# Stop conflicting processes or use different ports
```

### "Docker build fails"
```bash
# Clean up Docker
docker system prune -a

# Rebuild without cache
docker-compose build --no-cache
```

### "ArgoCD not syncing"
```bash
# Check ArgoCD application status
kubectl get applications -n argocd

# Force sync
argocd app sync microservices-demo
```

### "Pods keep crashing"
```bash
# Check pod logs
kubectl logs <pod-name> -n microservices-demo

# Describe pod for events
kubectl describe pod <pod-name> -n microservices-demo
```

---

## Summary

```
Your Code Journey:
                                                                    
  📝 Write Code                                                     
       │                                                            
       ▼                                                            
  📤 git push                                                       
       │                                                            
       ▼                                                            
  🔧 GitHub Actions                                                 
       │  └── Tests pass?                                          
       │       └── Yes → Build Docker images                       
       │                 └── Push to Docker Hub                    
       ▼                                                            
  👁️ ArgoCD watches Docker Hub                                     
       │  └── New image detected!                                  
       │       └── Update Kubernetes                               
       ▼                                                            
  ☸️ Kubernetes                                                     
       │  └── Pull new image                                       
       │       └── Restart containers                              
       ▼                                                            
  🎉 New version is LIVE!                                          
```

**That's it! Push code, everything else is automatic.**

---

## Next Steps

1. **Make a change**: Edit any file in `services/`
2. **Push to GitHub**: `git add . && git commit -m "test" && git push`
3. **Watch the magic**: Check GitHub Actions tab
4. **See the deployment**: Check ArgoCD UI or `kubectl get pods`

Happy coding! 🚀
