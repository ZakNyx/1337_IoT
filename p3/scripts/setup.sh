#!/bin/bash
set -e

# Create cluster with port mapping for the app
k3d cluster create iot -p "8888:8888@loadbalancer" --wait

echo "Cluster created. Checking nodes..."
kubectl get nodes
