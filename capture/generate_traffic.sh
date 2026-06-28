#!/bin/bash
# =============================================================
# generate_traffic.sh
# =============================================================
# PURPOSE : Generate labelled traffic for all 6 services
# RUN ON  : node-0
# USAGE   : bash capture/generate_traffic.sh <requests> <rate>
# EXAMPLE : bash capture/generate_traffic.sh 500 10
# NOTE    : Start capture/capture_per_service.sh on node-1
#           at the SAME TIME as this script
# =============================================================

set -e

REQUESTS=${1:-500}
RATE=${2:-10}
NAMESPACE="dissertation"
SLEEP_INTERVAL=$(echo "scale=3; 1/$RATE" | bc)
LOG_FILE="/tmp/traffic_log.txt"

# Time per service = requests/rate + buffer
SERVICE_DURATION=$(( (REQUESTS / RATE) + 60 ))

echo "================================================" > $LOG_FILE
echo " Traffic Generation Log" >> $LOG_FILE
echo " Date: $(date)" >> $LOG_FILE
echo " Requests per service: $REQUESTS" >> $LOG_FILE
echo " Target rate: $RATE req/sec" >> $LOG_FILE
echo " Service duration: ${SERVICE_DURATION}s" >> $LOG_FILE
echo "================================================" >> $LOG_FILE
echo "" >> $LOG_FILE

echo "=============================================="
echo " Traffic Generation"
echo " Requests per service : $REQUESTS"
echo " Rate                 : $RATE req/sec"
echo " Service duration     : ${SERVICE_DURATION}s"
echo " Total services       : 6"
echo " Log file             : $LOG_FILE"
echo "=============================================="
echo ""
echo " IMPORTANT: Start capture_per_service.sh on node-1"
echo " at the SAME TIME as this script!"
echo ""
echo " Starting in 10 seconds..."
echo " (giving you time to start node-1 script)"
sleep 10

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
echo ""

trigger_service() {
  local pod=$1
  local service=$2
  local count=$3
  local interval=$4

  local start_time=$(date +%s)
  local start_human=$(date '+%Y-%m-%d %H:%M:%S')

  echo "----------------------------------------------"
  echo " Service  : $service"
  echo " Start    : $start_human"
  echo "----------------------------------------------"

  kubectl exec -n $NAMESPACE $pod -- python3 -c "
import urllib.request, time

total = $count
interval = $interval
print(f'Sending {total} requests at {1/interval:.1f} req/sec')
start = time.time()

for i in range(1, total + 1):
    try:
        urllib.request.urlopen('http://localhost:5000/api/v1')
    except Exception as e:
        print(f'Request {i} failed: {e}')
    time.sleep(interval)
    if i % 100 == 0:
        elapsed = time.time() - start
        print(f'Progress: {i}/{total} | Rate: {i/elapsed:.1f} req/sec')

elapsed = time.time() - start
print(f'Done! {total} requests in {elapsed:.1f}s ({total/elapsed:.1f} req/sec)')
"

  local end_time=$(date +%s)
  local end_human=$(date '+%Y-%m-%d %H:%M:%S')
  local duration=$(( end_time - start_time ))
  local actual_rate=$(echo "scale=1; $count / $duration" | bc)

  echo " Completed: $service"
  echo " Duration : ${duration}s | Rate: ${actual_rate} req/sec"

  echo "Service: $service" >> $LOG_FILE
  echo "  Start      : $start_human" >> $LOG_FILE
  echo "  End        : $end_human" >> $LOG_FILE
  echo "  Duration   : ${duration}s" >> $LOG_FILE
  echo "  Actual rate: ${actual_rate} req/sec" >> $LOG_FILE
  echo "" >> $LOG_FILE

  # Wait for remaining duration so node-1 capture window aligns
  local elapsed=$(( end_time - start_time ))
  local remaining=$(( SERVICE_DURATION - elapsed ))
  if [ $remaining -gt 0 ]; then
    echo " Waiting ${remaining}s for capture window to complete..."
    sleep $remaining
  fi

  echo " Moving to next service..."
  echo ""
}

TOTAL_START=$(date +%s)

echo "=============================================="
echo " Starting traffic generation..."
echo "=============================================="

trigger_service "$PRODUCT_BROWSE" "product_browse" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$SEARCH" "search" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$ADD_TO_CART" "add_to_cart" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$CHECKOUT" "checkout" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$ORDER_HISTORY" "order_history" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$HEALTH" "health" "$REQUESTS" "$SLEEP_INTERVAL"

TOTAL_END=$(date +%s)
TOTAL_DURATION=$(( TOTAL_END - TOTAL_START ))

echo "" >> $LOG_FILE
echo "Total Duration: ${TOTAL_DURATION}s" >> $LOG_FILE
echo "Completed: $(date)" >> $LOG_FILE

echo "=============================================="
echo " All traffic generation complete!"
echo " Total time : ${TOTAL_DURATION}s"
echo " Log        : $LOG_FILE"
echo "=============================================="
echo ""
cat $LOG_FILE
