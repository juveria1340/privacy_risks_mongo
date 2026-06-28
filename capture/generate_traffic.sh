#!/bin/bash
# =============================================================
# generate_traffic.sh
# =============================================================
# PURPOSE : Generate labelled traffic for all 6 services
# RUN ON  : node-0
# USAGE   : bash capture/generate_traffic.sh <requests> <rate>
# EXAMPLE : bash capture/generate_traffic.sh 500 10
# NOTE    : Run capture/capture_per_service.sh on node-1 first!
# SIGNAL  : Uses /tmp/traffic_signal.txt to coordinate
#           with capture_per_service.sh (no Enter needed)
# =============================================================

set -e

REQUESTS=${1:-500}
RATE=${2:-10}
NAMESPACE="dissertation"
SLEEP_INTERVAL=$(echo "scale=3; 1/$RATE" | bc)
SIGNAL_FILE="/tmp/traffic_signal.txt"
LOG_FILE="/tmp/traffic_generation.log"

# Initialize log
echo "Traffic Generation Log" > $LOG_FILE
echo "======================" >> $LOG_FILE
echo "Date: $(date)" >> $LOG_FILE
echo "Requests per service: $REQUESTS" >> $LOG_FILE
echo "Rate: $RATE req/sec" >> $LOG_FILE
echo "Sleep interval: ${SLEEP_INTERVAL}s" >> $LOG_FILE
echo "" >> $LOG_FILE

echo "=============================================="
echo " Traffic Generation"
echo " Requests per service : $REQUESTS"
echo " Rate                 : $RATE req/sec"
echo " Sleep interval       : ${SLEEP_INTERVAL}s"
echo " Total requests       : $((REQUESTS * 6))"
echo " Est. time per service: $((REQUESTS / RATE)) seconds"
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
  echo " Requests : $count at $RATE req/sec"
  echo " Start    : $(date '+%Y-%m-%d %H:%M:%S')"
  echo "----------------------------------------------"

  # Signal capture script to start
  echo "START:$service" > $SIGNAL_FILE
  echo " Signal sent: START:$service"
  echo " Waiting 2 seconds for tcpdump to start..."
  sleep 2

  local start_time=$(date +%s)
  local start_human=$(date '+%Y-%m-%d %H:%M:%S')

  # Run loop INSIDE pod
  kubectl exec -n $NAMESPACE $pod -- python3 -c "
import urllib.request
import time

total = $count
interval = $interval

print(f'Starting {total} requests at {1/interval:.1f} req/sec')
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
        print(f'Progress: {i}/{total} | Rate: {rate:.1f} req/sec')

elapsed = time.time() - start
print(f'Done! {total} requests in {elapsed:.1f}s ({total/elapsed:.1f} req/sec)')
"

  local end_time=$(date +%s)
  local duration=$(( end_time - start_time ))
  local end_human=$(date '+%Y-%m-%d %H:%M:%S')

  # Signal capture script to stop
  echo "STOP:$service" > $SIGNAL_FILE
  echo " Signal sent: STOP:$service"

  # Log timing
  echo "Service: $service" >> $LOG_FILE
  echo "  Start:    $start_human" >> $LOG_FILE
  echo "  End:      $end_human" >> $LOG_FILE
  echo "  Duration: ${duration}s" >> $LOG_FILE
  echo "  Requests: $count" >> $LOG_FILE
  echo "  Avg rate: $(echo "scale=1; $count / $duration" | bc) req/sec" >> $LOG_FILE
  echo "" >> $LOG_FILE

  echo "  Completed : $service in ${duration}s"
  echo "  Waiting 5 seconds before next service..."
  sleep 5
}

TOTAL_START=$(date +%s)

echo ""
echo "=============================================="
echo " Starting traffic generation..."
echo " Signalling capture_per_service.sh on node-1"
echo "=============================================="

trigger_service "$PRODUCT_BROWSE" "product_browse" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$SEARCH" "search" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$ADD_TO_CART" "add_to_cart" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$CHECKOUT" "checkout" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$ORDER_HISTORY" "order_history" "$REQUESTS" "$SLEEP_INTERVAL"
trigger_service "$HEALTH" "health" "$REQUESTS" "$SLEEP_INTERVAL"

TOTAL_END=$(date +%s)
TOTAL_DURATION=$(( TOTAL_END - TOTAL_START ))

# Final signal
echo "DONE:all" > $SIGNAL_FILE

echo "" >> $LOG_FILE
echo "Total Duration: ${TOTAL_DURATION}s" >> $LOG_FILE
echo "Completed: $(date)" >> $LOG_FILE

echo ""
echo "=============================================="
echo " All traffic generation complete!"
echo " Total requests : $((REQUESTS * 6))"
echo " Total time     : ${TOTAL_DURATION}s"
echo " Log saved to   : $LOG_FILE"
echo "=============================================="
echo ""
echo " View log: cat $LOG_FILE"
echo " On node-1 run: bash capture/copy_captures.sh"
