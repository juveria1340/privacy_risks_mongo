#!/bin/bash
# =============================================================
# generate_traffic.sh
# =============================================================
# PURPOSE : Generate labelled traffic for all 6 services
# RUN ON  : node-0
# USAGE   : bash capture/generate_traffic.sh <requests> <rate>
# EXAMPLE : bash capture/generate_traffic.sh 500 10
# MANUAL  : Coordinate Enter key presses with node-1
# =============================================================

set -e

REQUESTS=${1:-500}
RATE=${2:-10}
NAMESPACE="dissertation"
SLEEP_INTERVAL=$(echo "scale=3; 1/$RATE" | bc)
LOG_FILE="/tmp/traffic_log.txt"

# Initialize log
echo "================================================" > $LOG_FILE
echo " Traffic Generation Log" >> $LOG_FILE
echo " Date: $(date)" >> $LOG_FILE
echo " Requests per service: $REQUESTS" >> $LOG_FILE
echo " Target rate: $RATE req/sec" >> $LOG_FILE
echo " Node: $(hostname)" >> $LOG_FILE
echo "================================================" >> $LOG_FILE
echo "" >> $LOG_FILE

echo "=============================================="
echo " Traffic Generation"
echo " Requests per service : $REQUESTS"
echo " Rate                 : $RATE req/sec"
echo " Sleep interval       : ${SLEEP_INTERVAL}s"
echo " Total requests       : $((REQUESTS * 6))"
echo " Log file             : $LOG_FILE"
echo "=============================================="

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

trigger_service() {
  local pod=$1
  local service=$2
  local count=$3
  local interval=$4

  echo ""
  echo "----------------------------------------------"
  echo " Service  : $service"
  echo " Pod      : $pod"
  echo " Requests : $count at $RATE req/sec"
  echo "----------------------------------------------"
  echo " Go to node-1 and press Enter to START tcpdump"
  echo " Then press Enter HERE to begin traffic..."
  read

  local start_time=$(date +%s)
  local start_human=$(date '+%Y-%m-%d %H:%M:%S')
  echo " [$start_human] Starting $service traffic..."

  # Run loop INSIDE pod - much faster than kubectl exec per request
  kubectl exec -n $NAMESPACE $pod -- python3 -c "
import urllib.request
import time

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
        rate = i / elapsed
        print(f'Progress: {i}/{total} | Elapsed: {elapsed:.0f}s | Rate: {rate:.1f} req/sec')

elapsed = time.time() - start
print(f'Done! {total} requests in {elapsed:.1f}s ({total/elapsed:.1f} req/sec)')
"

  local end_time=$(date +%s)
  local end_human=$(date '+%Y-%m-%d %H:%M:%S')
  local duration=$(( end_time - start_time ))
  local actual_rate=$(echo "scale=1; $count / $duration" | bc)

  echo ""
  echo " [$end_human] $service traffic COMPLETE"
  echo " Duration : ${duration}s"
  echo " Avg rate : ${actual_rate} req/sec"
  echo ""
  echo " --> Go to node-1 and press Enter to STOP tcpdump"
  echo " --> Then press Enter HERE to continue..."
  read

  # Log timing
  echo "Service: $service" >> $LOG_FILE
  echo "  Start      : $start_human" >> $LOG_FILE
  echo "  End        : $end_human" >> $LOG_FILE
  echo "  Duration   : ${duration}s" >> $LOG_FILE
  echo "  Requests   : $count" >> $LOG_FILE
  echo "  Actual rate: ${actual_rate} req/sec" >> $LOG_FILE
  echo "" >> $LOG_FILE

  echo " Waiting 5 seconds before next service..."
  sleep 5
}

TOTAL_START=$(date +%s)

echo ""
echo "=============================================="
echo " Starting traffic generation..."
echo " Coordinate Enter presses with node-1!"
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
echo "================================================" >> $LOG_FILE
echo " Summary" >> $LOG_FILE
echo " Total Duration: ${TOTAL_DURATION}s" >> $LOG_FILE
echo " Completed: $(date)" >> $LOG_FILE
echo "================================================" >> $LOG_FILE

echo ""
echo "=============================================="
echo " All traffic generation complete!"
echo " Total requests : $((REQUESTS * 6))"
echo " Total time     : ${TOTAL_DURATION}s"
echo " Log saved      : $LOG_FILE"
echo "=============================================="
echo ""
echo " View log : cat $LOG_FILE"
echo " On node-1: bash capture/copy_captures.sh"
