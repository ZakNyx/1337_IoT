#!/bin/bash

# Update the local package database
sudo apt-get update -y
sudo apt-get install -y curl

sudo fallocate -l 1G /swapfile
sudo chmod 600 /swapfile
sudo mkswap /swapfile
sudo swapon /swapfile
echo '/swapfile none swap sw 0 0' | sudo tee -a /etc/fstab
# ----------------------

# Install K3s strictly in server mode
echo "⚙️ Installing K3s..."
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --write-kubeconfig-mode 644" sh -
 
# Setup alias
echo "alias k='kubectl'" >> /home/vagrant/.bashrc

echo "✅ Server setup complete!"
