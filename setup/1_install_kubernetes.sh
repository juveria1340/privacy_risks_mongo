#!/bin/bash
# =============================================================
# 1_install_kubernetes.sh
# =============================================================
# PURPOSE : Install Kubernetes prerequisites on a CloudLab node
# RUN ON  : ALL nodes (node-0, node-1, node-2, node-3)
# USAGE   : bash setup/1_install_kubernetes.sh
# TIME    : ~5 minutes per node (run simultaneously on all)
# =============================================================

set -e

echo "=============================================="
echo " [1/4] Installing Kubernetes"
echo " Node: $(hostname)"
echo "=============================================="

# 1. Disable swap
echo ""
echo "--> Disabling swap..."
sudo swapoff -a
sudo sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
echo "    Done."

# 2. Load kernel modules
echo ""
echo "--> Loading kernel modules..."
sudo modprobe overlay
sudo modprobe br_netfilter
cat <<EOF | sudo tee /etc/modules-load.d/k8s.conf
overlay
br_netfilter
EOF
echo "    Done."

# 3. Set kernel parameters
echo ""
echo "--> Setting kernel parameters..."
cat <<EOF | sudo tee /etc/sysctl.d/k8s.conf
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF
sudo sysctl --system > /dev/null 2>&1
echo "    Done."

# 4. Install containerd
echo ""
echo "--> Installing containerd..."
sudo apt-get update -q
sudo apt-get install -y -q containerd apt-transport-https ca-certificates curl gnupg
sudo mkdir -p /etc/containerd
containerd config default | sudo tee /etc/containerd/config.toml > /dev/null
sudo sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
sudo systemctl restart containerd
sudo systemctl enable containerd
echo "    Done."

# 5. Install Kubernetes packages
echo ""
echo "--> Installing Kubernetes v1.28..."
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.28/deb/Release.key | \
  sudo gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg 2>/dev/null
echo 'deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.28/deb/ /' | \
  sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null
sudo apt-get update -q
sudo apt-get install -y -q kubelet kubeadm kubectl
sudo apt-mark hold kubelet kubeadm kubectl
sudo systemctl enable kubelet
echo "    Done."

echo ""
echo "=============================================="
echo " DONE on $(hostname)"
echo "=============================================="
echo ""
echo " Next: Run this script on all other nodes"
echo " Then on node-0 only: bash setup/2_init_cluster.sh"
