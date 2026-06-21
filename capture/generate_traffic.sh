#!/bin/bash
# =============================================================
# generate_traffic.sh
# =============================================================
# PURPOSE : Generate labelled traffic for all 6 services
# RUN ON  : node-0
# USAGE   : bash capture/generate_traffic.sh <requests_per_service>
# EXAMPLE : bash capture/generate_traffic.sh 100
# NOTE    : Run capture/capture_traffic.sh on node-1 first!
# =============================================================

set -e

REQUESTS=${1:-100}  # default 100 requests per service
NAMESPACE="dissertation"

echo "=============================================="
echo " Traffic Generation"
echo " Requests per service: $REQUESTS"
echo " Namespace: $NAMESPACE"
echo "=============================================="

# Get pod names
PRODUCT_BROWSE=$(kubectl get pod -n $NAMESPACE -l app=product-browse -o jsonpath='{.items[0].metadata.name}')
SEARCH=$(kubectl get pod -n $NAMESPACE -l app=search -o jsonpath='{.items[0].metadata.name}')
ADD_TO_CART=$(kubectl get pod -n $NAMESPACE -l app=add-to-cart -o jsonpath='{.items[0].metadata.name}')
CHECKOUT=$(kubectl get pod -n $NAMESPACE -l app=checkout -o jsonpath='{.items[0].metadata.name}')
ORDER_HISTORY=$(kubectl get pod -n $NAMESPACE -l app=order-history -o jsonpath='{.items[0].metadata.name}')
HEALTH=$(kubectl get pod -n $NAMESPACE -l app=health -o jsonpath='{.items[0].metadata.name}')

echo ""
echo "Pod names:"
echo "  product-browse : $PRODUCT_BROWSE"
echo "  search         : $SEARCH"
echo "  add-to-cart    : $ADD_TO_CART"
echo "  checkout       : $CHECKOUT"
echo "  order-history  : $ORDER_HISTORY"
echo "  health         : $HEALTH"

# Function to trigger a service N times
trigger_service() {
  local pod=$1
  local service=$2
  local count=$3

  echo ""
  echo "----------------------------------------------"
  echo " Triggering: $service ($count requests)"
  echo " Pod: $pod"
  echo "----------------------------------------------"

  # Signal to capture script which service is running
  echo "START:$service" > /tmp/current_service.txt

  for i in $(seq 1 $count); do
    kubectl exec -n $NAMESPACE $pod -- \
      python3 -c "
import urllib.request
urllib.request.urlopen('http://localhost:5000/api/v1')
" 2>/dev/null
    if [ $((i % 10)) -eq 0 ]; then
      echo "  Progress: $i/$count requests sent"
    fi
  done

  echo "DONE:$service" > /tmp/current_service.txt
  echo "  Completed: $service"
  # Small pause between services so captures are clean
  sleep 5
}

echo ""
echo "=============================================="
echo " Starting traffic generation..."
echo " Make sure capture_traffic.sh is running"
echo " on node-1 before proceeding!"
echo "=============================================="
echo ""
read -p "Press Enter when node-1 capture is ready..."

# Generate traffic for each service
trigger_service "$PRODUCT_BROWSE" "product_browse" "$REQUESTS"
trigger_service "$SEARCH" "search" "$REQUESTS"
trigger_service "$ADD_TO_CART" "add_to_cart" "$REQUESTS"
trigger_service "$CHECKOUT" "checkout" "$REQUESTS"
trigger_service "$ORDER_HISTORY" "order_history" "$REQUESTS"
trigger_service "$HEALTH" "health" "$REQUESTS"

echo ""
echo "=============================================="
echo " Traffic generation complete!"
echo " Total requests: $((REQUESTS * 6))"
echo "=============================================="
echo ""
echo " Now on node-1 press Ctrl+C to stop capture"
echo " Then run: bash capture/copy_captures.sh"
