#!/bin/bash
# =============================================================
# generate_traffic.sh
# =============================================================
# PURPOSE : Generate labelled traffic for all 6 services
# RUN ON  : node-0
# USAGE   : bash capture/generate_traffic.sh <requests> <rate>
# EXAMPLE : bash capture/generate_traffic.sh 1000 10
# NOTE    : Run capture/capture_per_service.sh on node-1 first!
#
# JUSTIFICATION:
# Traffic is generated at a controlled rate using sleep intervals
# between requests. This produces consistent inter-arrival times
# between flows, making the dataset reproducible across runs.
# Rate is calculated as: sleep = 1/rate seconds between requests
# =============================================================

set -e

REQUESTS=${1:-1000}   # default 1000 requests per service
RATE=${2:-10}         # default 10 requests per second
NAMESPACE="dissertation"
SLEEP_INTERVAL=$(echo "scale=3; 1/$RATE" | bc)

echo "=============================================="
echo " Traffic Generation"
echo " Requests per service : $REQUESTS"
echo " Rate                 : $RATE req/sec"
echo " Sleep interval       : ${SLEEP_INTERVAL}s between requests"
echo " Total requests       : $((REQUESTS * 6))"
echo " Est. time per service: $((REQUESTS / RATE)) seconds"
echo "=============================================="

# Get pod names dynamically
get_pod() {
  kubectl get pod -n $NAMESPACE -l app=$1 \
    -o jsonpath='{.items[0].metadata.name}'
}

echo ""
echo "Resolving pod names..."
PRODUCT_BROWSE=$(get_pod "product-browse")
SEARCH=$(get_pod "search")
ADD_TO_CART=$(get_pod "add-to-cart")
CHECKOUT=$(get_pod "checkout")
ORDER_HISTORY=$(get_pod "order-history")
HEALTH=$(get_pod "health")

echo "  product-browse : $PRODUCT_BROWSE"
echo "  search         : $SEARCH"
echo "  add-to-cart    : $ADD_TO_CART"
echo "  checkout       : $CHECKOUT"
echo "  order-history  : $ORDER_HISTORY"
echo "  health         : $HEALTH"

# Function to trigger a service at controlled rate
trigger_service() {
  local pod=$1
  local service=$2
  local count=$3
  local interval=$4
  local start_time=$(date +%s)

  echo ""
  echo "----------------------------------------------"
  echo " Service  : $service"
  echo " Pod      : $pod"
  echo " Requests : $count at $RATE req/sec"
  echo " Start    : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "----------------------------------------------"
  echo " Make sure tcpdump is capturing on node-1!"
  read -p " Press Enter to start $service..."

  for i in $(seq 1 $count); do
    kubectl exec -n $NAMESPACE $pod -- \
      python3 -c "
import urllib.request
urllib.request.urlopen('http://localhost:5000/api/v1')
" 2>/dev/null

    # Rate control
    sleep $interval

    # Progress update every 50 requests
    if [ $((i % 50)) -eq 0 ]; then
      elapsed=$(( $(date +%s) - start_time ))
      actual_rate=$(echo "scale=1; $i / $elapsed" | bc 2>/dev/null || echo "~$RATE")
      echo "  Progress: $i/$count requests | Elapsed: ${elapsed}s | Rate: ${actual_rate} req/sec"
    fi
  done

  local end_time=$(date +%s)
  local duration=$(( end_time - start_time ))
  local actual_rate=$(echo "scale=1; $count / $duration" | bc 2>/dev/null || echo "~$RATE")

  echo ""
  echo "  Completed: $service"
  echo "  Duration : ${duration}s"
  echo "  Avg rate : ${actual_rate} req/sec"
  echo "  Press Enter when tcpdump capture is stopped for $service..."
  read

  # Pause between services for clean separation
  echo "  Waiting 5 seconds before next service..."
  sleep 5
}

echo ""
echo "=============================================="
echo " Starting traffic generation..."
echo " Coordinate with node-1 capture script!"
echo "=============================================="

# Generate traffic for each service
trigger_service "$PRODUCT_BROWSE" "product_browse" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$SEARCH" "search" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$ADD_TO_CART" "add_to_cart" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$CHECKOUT" "checkout" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$ORDER_HISTORY" "order_history" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$HEALTH" "health" "$REQUESTS" "$SLEEP_INTERVAL"

echo ""
echo "=============================================="
echo " All traffic generation complete!"
echo " Total requests sent: $((REQUESTS * 6))"
echo " Services captured  : 6"
echo "=============================================="
echo ""

