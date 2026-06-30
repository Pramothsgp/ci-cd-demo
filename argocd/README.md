# Argo CD Installation and Configuration Guide
# 
# This directory contains Argo CD Application manifests for GitOps deployment.
# 
# Prerequisites:
# 1. Minikube or K8s cluster running
# 2. kubectl configured
#
# Installation Steps:
# 1. Create namespace: kubectl create namespace argocd
# 2. Install Argo CD: kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml
# 3. Wait for pods: kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s
# 4. Get admin password: kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
# 5. Port forward: kubectl port-forward svc/argocd-server -n argocd 8080:443
# 6. Access UI: https://localhost:8080 (username: admin, password: from step 4)
#
# Apply applications:
# kubectl apply -f applications/
