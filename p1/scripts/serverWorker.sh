#!/bin/bash

# Update the local package database
sudo apt-get update -y

# Identify the Server and the Password
# K3S_URL: The address of the API server (zihirriS).
# K3S_TOKEN: MUST match the token in the server script.
export K3S_URL="https://192.168.56.110:6443"
export K3S_TOKEN="zihirri_secret_token"

# Install K3s in Agent mode
# --node-ip: Tells the server exactly where this worker is located.
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="agent --node-ip=192.168.56.111" sh -

# 4. Create an alias
echo "alias k='kubectl'" >> /home/vagrant/.bashrc

