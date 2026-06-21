#!/bin/bash
# =============================================================
# 2_init_cluster.sh
# =============================================================
# PURPOSE : Initialise Kubernetes cluster + join worker nodes
# RUN ON  : node-0 ONLY
# USAGE   : bash setup/2_init_cluster.sh
# PREREQ  : 1_install_kubernetes.sh run on ALL nodes first
# TIME    : ~5 minutes
# =============================================================

set -e

echo "=============================================="
echo " [2/4] Initialising Kubernetes Cluster"
echo " Control plane: $(hostname)"
echo "=============================================="

# 1. Init control plane
echo ""
echo "--> Initialising control plane..."
NODE0_IP=$(ip route get 8.8.8.8 | awk '{print $7; exit}')
echo "    IP: $NODE0_IP"

sudo kubeadm init \
  --pod-network-cidr=10.244.0.0/16 \
  --apiserver-advertise-address=$NODE0_IP \
  --ignore-preflight-errors=all 2>&1 | tee /tmp/kubeadm-init.log

echo "    Control plane initialised!"

# 2. Configure kubectl
echo ""
echo "--> Configuring kubectl..."
mkdir -p $HOME/.kube
sudo cp -i /etc/kubernetes/admin.conf $HOME/.kube/config
sudo chown $(id -u):$(id -g) $HOME/.kube/config
echo "    Done."

# 3. Install Flannel
echo ""
echo "--> Installing Flannel network plugin..."
kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml
echo "    Done."

# 4. Wait for control plane
echo ""
echo "--> Waiting for control plane to be Ready..."
sleep 30
# Wait for control plane using label instead of hostname
sleep 30
kubectl wait --for=condition=ready node \
  --selector=node-role.kubernetes.io/control-plane \
  --timeout=120s
echo "    Ready!"

# 5. Save join command
echo ""
echo "--> Extracting join command..."
JOIN_CMD=$(grep -A2 "kubeadm join" /tmp/kubeadm-init.log | tr -d '\\\n' | sed 's/^[[:space:]]*//')
echo "sudo $JOIN_CMD --ignore-preflight-errors=all" > /tmp/join_command.sh
chmod +x /tmp/join_command.sh

echo ""
echo "=============================================="
echo " Cluster initialised!"
echo "=============================================="
echo ""
echo " Current nodes:"
kubectl get nodes
echo ""
echo " RUN THIS ON node-1, node-2, node-3:"
echo " ----------------------------------------"
cat /tmp/join_command.sh
echo " ----------------------------------------"
echo ""
echo " After all nodes join run on node-0:"
echo "   bash setup/3_generate_certs.sh"

