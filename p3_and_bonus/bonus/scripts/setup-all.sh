#!/bin/bash
set -e

echo "=== Step 1: Clean up ==="
k3d cluster delete iot 2>/dev/null || true

echo "=== Step 2: Create K3d cluster ==="
k3d cluster create iot \
  -p "8888:8888@loadbalancer" \
  -p "8443:443@loadbalancer" \
  -p "9090:80@loadbalancer" \
  --agents 1 \
  --wait

echo "=== Step 3: Create namespaces ==="
kubectl create namespace argocd
kubectl create namespace dev
kubectl create namespace gitlab

echo "=== Step 4: Install Argo CD ==="
kubectl apply -n argocd -f https://raw.githubusercontent.com/argoproj/argo-cd/stable/manifests/install.yaml --server-side --force-conflicts
echo "Waiting for Argo CD pods..."
kubectl wait --for=condition=Ready pods --all -n argocd --timeout=300s

echo ""
echo "Argo CD admin password:"
kubectl -n argocd get secret argocd-initial-admin-secret -o jsonpath="{.data.password}" | base64 -d
echo ""

echo "=== Step 5: Deploy GitLab CE ==="
kubectl apply -f bonus/confs/gitlab-deployment.yaml
kubectl apply -f bonus/confs/gitlab-service.yaml

echo "Waiting for GitLab pod to be ready (this takes 3-5 min)..."
kubectl wait --for=condition=Ready pods -l app=gitlab -n gitlab --timeout=600s

echo ""
echo "GitLab credentials: root / P@ssw0rd123!"
echo ""

echo "=== Step 6: Wait for GitLab to fully initialize ==="
echo "GitLab needs ~2 min after pod is Ready to finish internal setup..."
sleep 120

echo "=== SETUP COMPLETE ==="
echo ""
echo "Next manual steps:"
echo "1. Port-forward GitLab:  kubectl port-forward svc/gitlab -n gitlab 9090:80 &"
echo "2. Open http://localhost:9090 and login (root / P@ssw0rd123!)"
echo "3. Create project 'iot-app' and push manifests"
echo "4. Register repo in Argo CD and apply the app manifest"
echo ""
echo "To access Argo CD:  kubectl port-forward svc/argocd-server -n argocd 8080:443 &"
echo "To access the app:  kubectl port-forward svc/wil-playground -n dev 8888:8888 &"
