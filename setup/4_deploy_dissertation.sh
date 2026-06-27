#!/bin/bash
# =============================================================
# 4_deploy_dissertation.sh
# =============================================================
# PURPOSE : Deploy MongoDB + Flask pods on Kubernetes
# RUN ON  : node-0
# USAGE   : bash setup/4_deploy_dissertation.sh
# PREREQ  : Scripts 1, 2, 3 must have completed successfully
# TIME    : ~10 minutes
# =============================================================

set -e

REPO_DIR="$(cd "$(dirname $0)/.." && pwd)"
NAMESPACE="dissertation"

echo "=============================================="
echo " [4/4] Deploying Dissertation Environment"
echo " Repo: $REPO_DIR"
echo "=============================================="

# 1. Label nodes
echo ""
echo "--> [1/8] Labelling nodes..."
# Get node names sorted alphabetically
CONTROL=$(kubectl get nodes --no-headers | grep "control-plane" | awk '{print $1}')
WORKERS=($(kubectl get nodes --no-headers | grep -v "control-plane" | awk '{print $1}' | sort))
kubectl label node $CONTROL role=control-plane --overwrite
kubectl label node ${WORKERS[0]} role=mongo-node --overwrite
kubectl label node ${WORKERS[1]} role=app-node --overwrite
kubectl label node ${WORKERS[2]} role=capture-node --overwrite
kubectl get nodes -L role
echo "    Done."

# 2. Create namespace
echo ""
echo "--> [2/8] Creating namespace..."
kubectl apply -f $REPO_DIR/kubernetes/mongodb/namespace.yaml
echo "    Done."

# 3. Create TLS secret
echo ""
echo "--> [3/8] Creating TLS secret..."
kubectl create secret generic mongodb-tls \
  --from-file=ca.crt=$REPO_DIR/kubernetes/mongodb/certs/ca.crt \
  --from-file=mongo.pem=$REPO_DIR/kubernetes/mongodb/certs/mongo.pem \
  --namespace $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -
echo "    Done."

# 4. Deploy MongoDB
echo ""
echo "--> [4/8] Deploying MongoDB with TLS..."
kubectl apply -f $REPO_DIR/kubernetes/mongodb/deployment.yaml
kubectl apply -f $REPO_DIR/kubernetes/mongodb/service.yaml
echo "    Waiting for MongoDB to be ready..."
kubectl wait --for=condition=ready pod \
  -l app=mongodb -n $NAMESPACE --timeout=180s
echo "    MongoDB ready!"

# 5a. Create seed data ConfigMap from CSV
echo ""
echo "--> [5a/8] Creating seed data ConfigMap from CSV..."
kubectl create configmap seed-data \
  --from-file=amazon.csv=$REPO_DIR/data/seed/amazon.csv \
  --namespace $NAMESPACE \
  --dry-run=client -o yaml | kubectl apply -f -
echo "    Done."

# 5. Seed MongoDB
echo ""
echo "--> [5/8] Seeding MongoDB with e-commerce data..."
kubectl apply -f $REPO_DIR/kubernetes/mongodb/seed-configmap.yaml
kubectl delete job mongodb-seed -n $NAMESPACE --ignore-not-found=true
kubectl apply -f $REPO_DIR/kubernetes/mongodb/seed-job.yaml
echo "    Waiting for seed job..."
kubectl wait --for=condition=complete job/mongodb-seed \
  -n $NAMESPACE --timeout=600s
kubectl logs -n $NAMESPACE \
  $(kubectl get pod -n $NAMESPACE -l job-name=mongodb-seed \
    -o jsonpath='{.items[0].metadata.name}') | tail -8
echo "    MongoDB seeded!"

# 6. Create ConfigMaps
echo ""
echo "--> [6/8] Creating Flask service ConfigMaps..."
for service in product_browse search add_to_cart checkout order_history health; do
  name=$(echo $service | tr '_' '-')
  kubectl create configmap ${name}-script \
    --from-file=${service}.py=$REPO_DIR/services/${service}.py \
    --namespace $NAMESPACE \
    --dry-run=client -o yaml | kubectl apply -f -
  echo "    ${name}-script created"
done
echo "    Done."

# 7. Deploy Flask pods
echo ""
echo "--> [7/8] Deploying Flask service pods..."
kubectl apply -f $REPO_DIR/kubernetes/workloads/
echo "    Waiting for all pods to be ready..."
kubectl wait --for=condition=ready pod \
  -l workload=ecommerce -n $NAMESPACE --timeout=600s
echo "    All pods ready!"

# 8. Verify
echo ""
echo "--> [8/8] Verifying deployment..."
kubectl get pods -n $NAMESPACE -o wide

echo ""
echo "=============================================="
echo " Deployment Complete!"
echo "=============================================="
echo ""
echo " Next: SSH into node-3 then run:"
echo "   bash capture/capture_traffic.sh"



