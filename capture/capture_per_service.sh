#!/bin/bash
# =============================================================
# capture_per_service.sh
# =============================================================
# PURPOSE : Capture traffic per service with automatic labelling
# RUN ON  : node-1 (mongo-node)
# USAGE   : bash capture/capture_per_service.sh
# NOTE    : Automatically coordinates with generate_traffic.sh
#           via signal file /tmp/traffic_signal.txt on node-0
#           No manual Enter key presses needed!
# =============================================================

CAPTURE_DIR="/tmp/captures"
mkdir -p $CAPTURE_DIR

INTERFACE="cni0"
SIGNAL_FILE="/tmp/traffic_signal.txt"
LOG_FILE="/tmp/capture_log.txt"
NODE0="node-0"

# Initialize log
echo "Capture Log" > $LOG_FILE
echo "===========" >> $LOG_FILE
echo "Date: $(date)" >> $LOG_FILE
echo "Interface: $INTERFACE" >> $LOG_FILE
echo "" >> $LOG_FILE

echo "=============================================="
echo " Per-Service Traffic Capture"
echo " Interface : $INTERFACE"
echo " Port      : 27017 (MongoDB TLS)"
echo " Output    : $CAPTURE_DIR"
echo " Log       : $LOG_FILE"
echo "=============================================="

SERVICES=(
  "product_browse"
  "search"
  "add_to_cart"
  "checkout"
  "order_history"
  "health"
)

wait_for_signal() {
  local expected=$1
  echo " Waiting for signal: $expected"
  while true; do
    # Read signal from node-0
    SIGNAL=$(ssh -o StrictHostKeyChecking=no $NODE0 \
      "cat $SIGNAL_FILE 2>/dev/null || echo 'NONE'" 2>/dev/null)
    if [[ "$SIGNAL" == *"$expected"* ]]; then
      echo " Signal received: $SIGNAL"
      break
    fi
    sleep 1
  done
}

for service in "${SERVICES[@]}"; do
  echo ""
  echo "----------------------------------------------"
  echo " Waiting to capture: $service"
  echo "----------------------------------------------"

  # Wait for START signal from node-0
  wait_for_signal "START:$service"

  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  OUTFILE="$CAPTURE_DIR/${service}_${TIMESTAMP}.pcap"
  START_TIME=$(date +%s)
  START_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')

  echo " Starting tcpdump -> $OUTFILE"
  sudo tcpdump -i $INTERFACE \
    port 27017 \
    -w $OUTFILE \
    -q &
  TCPDUMP_PID=$!
  echo " tcpdump running (PID: $TCPDUMP_PID)"

  # Wait for STOP signal from node-0
  wait_for_signal "STOP:$service"

  # Give tcpdump 2 more seconds to flush remaining packets
  sleep 2
  kill $TCPDUMP_PID 2>/dev/null
  wait $TCPDUMP_PID 2>/dev/null || true

  END_TIME=$(date +%s)
  END_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')
  DURATION=$(( END_TIME - START_TIME ))
  SIZE=$(ls -lh $OUTFILE 2>/dev/null | awk '{print $5}')
  PACKETS=$(tcpdump -r $OUTFILE 2>/dev/null | wc -l || echo "unknown")

  echo " Capture complete!"
  echo "   File    : $OUTFILE"
  echo "   Size    : $SIZE"
  echo "   Packets : $PACKETS"
  echo "   Duration: ${DURATION}s"

  # Log details
  echo "Service: $service" >> $LOG_FILE
  echo "  File     : $OUTFILE" >> $LOG_FILE
  echo "  Start    : $START_HUMAN" >> $LOG_FILE
  echo "  End      : $END_HUMAN" >> $LOG_FILE
  echo "  Duration : ${DURATION}s" >> $LOG_FILE
  echo "  Size     : $SIZE" >> $LOG_FILE
  echo "  Packets  : $PACKETS" >> $LOG_FILE
  echo "" >> $LOG_FILE

  sleep 3
done

echo ""
echo "=============================================="
echo " All captures complete!"
echo "=============================================="
echo ""
ls -lh $CAPTURE_DIR
echo ""
echo " Capture log:"
cat $LOG_FILE
echo ""
echo " Run: bash capture/copy_captures.sh"
echo " to get commands to copy files to your laptop"
