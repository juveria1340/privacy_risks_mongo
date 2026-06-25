#!/bin/bash
# =============================================================
# restart_dissertation.sh
# =============================================================
# PURPOSE : Restart all dissertation pods after
#           "kubectl delete deployments --all -n dissertation"
# RUN ON  : node-0
# USAGE   : bash setup/restart_dissertation.sh
# TIME    : ~5 minutes
# =============================================================

set -e

REPO_DIR="$(cd "$(dirname $0)/.." && pwd)"
NAMESPACE="dissertation"

echo "=============================================="
echo " Restarting Dissertation Environment"
echo " Repo: $REPO_DIR"
echo "=============================================="

# Step 1: Deploy MongoDB
echo ""
echo "--> [1/4] Deploying MongoDB..."
kubectl apply -f $REPO_DIR/kubernetes/mongodb/deployment.yaml
kubectl apply -f $REPO_DIR/kubernetes/mongodb/service.yaml
echo "    Waiting for MongoDB to be ready..."
kubectl wait --for=condition=ready pod \
  -l app=mongodb -n $NAMESPACE --timeout=180s
echo "    MongoDB ready!"

# Step 2: Verify TLS secret exists
echo ""
echo "--> [2/4] Checking TLS secret..."
if kubectl get secret mongodb-tls -n $NAMESPACE > /dev/null 2>&1; then
  echo "    TLS secret exists."
else
  echo "    TLS secret missing! Recreating..."
  kubectl create secret generic mongodb-tls \
    --from-file=ca.crt=$REPO_DIR/kubernetes/mongodb/certs/ca.crt \
    --from-file=mongo.pem=$REPO_DIR/kubernetes/mongodb/certs/mongo.pem \
    --namespace $NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "    TLS secret recreated."
fi

# Step 3: Verify ConfigMaps exist
echo ""
echo "--> [3/4] Checking Flask ConfigMaps..."
for service in product_browse search add_to_cart checkout order_history health; do
  name=$(echo $service | tr '_' '-')
  if kubectl get configmap ${name}-script -n $NAMESPACE > /dev/null 2>&1; then
    echo "    ${name}-script exists."
  else
    echo "    ${name}-script missing! Recreating..."
    kubectl create configmap ${name}-script \
      --from-file=${service}.py=$REPO_DIR/services/${service}.py \
      --namespace $NAMESPACE \
      --dry-run=client -o yaml | kubectl apply -f -
    echo "    ${name}-script recreated."
  fi
done

# Step 4: Deploy Flask pods
echo ""
echo "--> [4/4] Deploying Flask service pods..."
kubectl apply -f $REPO_DIR/kubernetes/workloads/
echo "    Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod \
  -l workload=ecommerce -n $NAMESPACE --timeout=600s
echo "    All pods ready!"

echo ""
echo "=============================================="
echo " Restart Complete!"
echo "=============================================="
echo ""
kubectl get pods -n $NAMESPACE -o wide
echo ""
echo " Next steps:"
echo "   Capture traffic: bash capture/capture_per_service.sh"
echo "   Generate traffic: bash capture/generate_traffic.sh"
