#!/bin/bash
# =============================================================
# capture_per_service.sh
# =============================================================
# PURPOSE : Capture per-service traffic using fixed time windows
# RUN ON  : node-1 (mongo-node)
# USAGE   : bash capture/capture_per_service.sh <requests> <rate>
# EXAMPLE : bash capture/capture_per_service.sh 500 10
# NOTE    : Start generate_traffic.sh on node-0 AT SAME TIME
#           No manual coordination needed!
# =============================================================

REQUESTS=${1:-500}
RATE=${2:-10}
CAPTURE_DIR="/tmp/captures"
mkdir -p $CAPTURE_DIR

INTERFACE="cni0"
LOG_FILE="/tmp/capture_log.txt"

# Match duration with generate_traffic.sh
SERVICE_DURATION=$(( (REQUESTS / RATE) + 60 ))

echo "================================================" > $LOG_FILE
echo " Traffic Capture Log" >> $LOG_FILE
echo " Date: $(date)" >> $LOG_FILE
echo " Interface: $INTERFACE" >> $LOG_FILE
echo " Service duration: ${SERVICE_DURATION}s" >> $LOG_FILE
echo "================================================" >> $LOG_FILE
echo "" >> $LOG_FILE

echo "=============================================="
echo " Per-Service Traffic Capture"
echo " Interface       : $INTERFACE"
echo " Port            : 27017 (MongoDB TLS)"
echo " Output          : $CAPTURE_DIR"
echo " Service duration: ${SERVICE_DURATION}s"
echo " Log             : $LOG_FILE"
echo "=============================================="
echo ""
echo " IMPORTANT: Start generate_traffic.sh on node-0"
echo " at the SAME TIME as this script!"
echo ""
echo " Starting in 10 seconds..."
sleep 10

SERVICES=(
  "product_browse"
  "search"
  "add_to_cart"
  "checkout"
  "order_history"
  "health"
)

TOTAL_START=$(date +%s)

for service in "${SERVICES[@]}"; do
  echo ""
  echo "----------------------------------------------"
  echo " Capturing: $service"
  echo " Duration : ${SERVICE_DURATION}s"
  echo "----------------------------------------------"

  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  OUTFILE="$CAPTURE_DIR/${service}_${TIMESTAMP}.pcap"
  START_TIME=$(date +%s)
  START_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')

  echo " [$START_HUMAN] tcpdump STARTED"
  echo " File: $OUTFILE"

  # Run tcpdump for fixed duration
  sudo timeout $SERVICE_DURATION tcpdump \
    -i $INTERFACE \
    port 27017 \
    -w $OUTFILE \
    -q 2>/dev/null

  END_TIME=$(date +%s)
  END_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')
  DURATION=$(( END_TIME - START_TIME ))
  SIZE=$(ls -lh $OUTFILE 2>/dev/null | awk '{print $5}')
  PACKETS=$(sudo tcpdump -r $OUTFILE 2>/dev/null | wc -l)

  echo " [$END_HUMAN] tcpdump STOPPED"
  echo " Duration : ${DURATION}s"
  echo " Size     : $SIZE"
  echo " Packets  : $PACKETS"

  echo "Service: $service" >> $LOG_FILE
  echo "  Start    : $START_HUMAN" >> $LOG_FILE
  echo "  End      : $END_HUMAN" >> $LOG_FILE
  echo "  Duration : ${DURATION}s" >> $LOG_FILE
  echo "  File     : $OUTFILE" >> $LOG_FILE
  echo "  Size     : $SIZE" >> $LOG_FILE
  echo "  Packets  : $PACKETS" >> $LOG_FILE
  echo "" >> $LOG_FILE
done

TOTAL_END=$(date +%s)
TOTAL_DURATION=$(( TOTAL_END - TOTAL_START ))

echo "" >> $LOG_FILE
echo "Total Duration: ${TOTAL_DURATION}s" >> $LOG_FILE
echo "Completed: $(date)" >> $LOG_FILE

echo ""
echo "=============================================="
echo " All captures complete!"
echo " Total time: ${TOTAL_DURATION}s"
echo "=============================================="
echo ""
ls -lh $CAPTURE_DIR
echo ""
echo "Full capture log:"
cat $LOG_FILE
echo ""
echo "Run: bash capture/copy_captures.sh"
