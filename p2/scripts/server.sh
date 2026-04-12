#!/bin/bash

# Update packages
sudo apt-get update -y

# Install K3s strictly in server mode
curl -sfL https://get.k3s.io | INSTALL_K3S_EXEC="server --node-ip=192.168.56.110 --write-kubeconfig-mode 644" sh -

# Setup alias
echo "alias k='kubectl'" >> /home/vagrant/.bashrc