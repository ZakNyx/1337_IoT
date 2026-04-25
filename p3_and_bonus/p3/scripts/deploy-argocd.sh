#!/bin/bash
set -e

# Create namespaces
kubectl apply -f p3/confs/argocd-namespace.yaml
kubectl apply -f p3/confs/dev-namespace.yaml

# Install Argo CD
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml

echo "Waiting for Argo CD pods to be ready..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

# Get the initial admin password
echo ""
echo "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

# Port-forward Argo CD UI (run in background)
echo ""
echo "Starting port-forward for Argo CD UI on https://localhost:8080..."
kubectl port-forward svc/argocd-server -n argocd 8080:443 &

echo "Argo CD is ready. Access it at https://localhost:8080 (user: admin)"
