#!/bin/bash

# Update the local package database
sudo apt-get update -y

# Define the shared secret (The Token)
# This is the "password" the worker will use to join.
export K3S_TOKEN="zihirri_secret_token"

# Install K3s in Server mode
# --node-ip: Forces K3s to use the static IP we set in Vagrant.
# --write-kubeconfig-mode 644: Allows the 'vagrant' user to use kubectl without sudo.
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --write-kubeconfig-mode 644" sh -

# 4. Create an alias for ease of use (Optional but helpful for the defense)
echo "alias k='kubectl'" >> /home/vagrant/.bashrc