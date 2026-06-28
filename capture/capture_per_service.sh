#!/bin/bash
# capture_per_service.sh
# RUN ON: node-1

CAPTURE_DIR="/tmp/captures"
mkdir -p $CAPTURE_DIR
INTERFACE="cni0"
LOG_FILE="/tmp/capture_log.txt"

echo "================================================" > $LOG_FILE
echo " Traffic Capture Log" >> $LOG_FILE
echo " Date: $(date)" >> $LOG_FILE
echo "================================================" >> $LOG_FILE
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

TOTAL_START=$(date +%s)

for service in "${SERVICES[@]}"; do
  echo ""
  echo "----------------------------------------------"
  echo " Next service: $service"
  echo "----------------------------------------------"
  echo " Go to node-0 and start traffic for: $service"
  printf " Press Enter HERE to START tcpdump... "
  read REPLY </dev/tty

  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  OUTFILE="$CAPTURE_DIR/${service}_${TIMESTAMP}.pcap"
  START_TIME=$(date +%s)
  START_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')

  echo " [$START_HUMAN] tcpdump STARTED for $service"
  echo " File: $OUTFILE"

  # Redirect ALL tcpdump output to /dev/null
  sudo tcpdump -i $INTERFACE \
    port 27017 \
    -w $OUTFILE \
    -q 2>/dev/null 1>/dev/null &
  TCPDUMP_PID=$!

  echo " tcpdump PID: $TCPDUMP_PID"
  printf " Press Enter to STOP when traffic is complete... "
  read REPLY </dev/tty

  sudo kill $TCPDUMP_PID 2>/dev/null
  wait $TCPDUMP_PID 2>/dev/null || true
  sleep 1

  END_TIME=$(date +%s)
  END_HUMAN=$(date '+%Y-%m-%d %H:%M:%S')
  DURATION=$(( END_TIME - START_TIME ))
  SIZE=$(ls -lh $OUTFILE 2>/dev/null | awk '{print $5}')
  PACKETS=$(sudo tcpdump -r $OUTFILE 2>/dev/null | wc -l)

  echo ""
  echo " [$END_HUMAN] tcpdump STOPPED for $service"
  echo " Duration : ${DURATION}s"
  echo " File size: $SIZE"
  echo " Packets  : $PACKETS"

  echo "Service: $service" >> $LOG_FILE
  echo "  Start    : $START_HUMAN" >> $LOG_FILE
  echo "  End      : $END_HUMAN" >> $LOG_FILE
  echo "  Duration : ${DURATION} seconds" >> $LOG_FILE
  echo "  File     : $OUTFILE" >> $LOG_FILE
  echo "  Size     : $SIZE" >> $LOG_FILE
  echo "  Packets  : $PACKETS" >> $LOG_FILE
  echo "" >> $LOG_FILE

  echo " Waiting 3 seconds before next service..."
  sleep 3
done

TOTAL_END=$(date +%s)
TOTAL_DURATION=$(( TOTAL_END - TOTAL_START ))

echo "" >> $LOG_FILE
echo "Total Duration: ${TOTAL_DURATION}s" >> $LOG_FILE
echo "Completed: $(date)" >> $LOG_FILE

echo ""
echo "=============================================="
echo " All captures complete! Total time: ${TOTAL_DURATION}s"
echo "=============================================="
ls -lh $CAPTURE_DIR
echo ""
cat $LOG_FILE
echo ""
echo " Run: bash capture/copy_captures.sh"
