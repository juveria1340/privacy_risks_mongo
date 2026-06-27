#!/bin/bash
# =============================================================
# capture_per_service.sh
# =============================================================
# PURPOSE : Capture traffic per service with automatic labelling
# RUN ON  : node-1 (mongo-node)
# USAGE   : bash capture/capture_per_service.sh <requests>
# EXAMPLE : bash capture/capture_per_service.sh 100
# NOTE    : Coordinate with generate_traffic.sh on node-0
# =============================================================

REQUESTS=${1:-100}
CAPTURE_DIR="/tmp/captures"
mkdir -p $CAPTURE_DIR

# Find correct interface
INTERFACE="cni0"
echo "=============================================="
echo " Per-Service Traffic Capture"
echo " Interface : $INTERFACE"
echo " Port      : 27017 (MongoDB TLS)"
echo " Output    : $CAPTURE_DIR"
echo "=============================================="

# Services in order matching generate_traffic.sh
SERVICES=(
  "product_browse"
  "search"
  "add_to_cart"
  "checkout"
  "order_history"
  "health"
)

# Estimated time per service (requests * ~0.5s per request)
DURATION=$(( REQUESTS + 30 ))

for service in "${SERVICES[@]}"; do
  echo ""
  echo "----------------------------------------------"
  echo " Capturing: $service"
  echo " Duration : ~${DURATION} seconds"
  echo "----------------------------------------------"
  echo " Waiting for generate_traffic.sh to start $service..."
  echo " Press Enter to start capture for $service"
  read

  TIMESTAMP=$(date +%Y%m%d_%H%M%S)
  OUTFILE="$CAPTURE_DIR/${service}_${TIMESTAMP}.pcap"

  echo " Starting tcpdump -> $OUTFILE"
  sudo timeout $DURATION tcpdump -i $INTERFACE \
    port 27017 \
    -w $OUTFILE \
    -q 2>/dev/null &

  TCPDUMP_PID=$!
  echo " tcpdump running (PID: $TCPDUMP_PID)"
  echo " Capturing for ${DURATION} seconds..."

  wait $TCPDUMP_PID 2>/dev/null || true

  SIZE=$(ls -lh $OUTFILE | awk '{print $5}')
  echo " Capture complete: $OUTFILE ($SIZE)"
done

echo ""
echo "=============================================="
echo " All captures complete!"
echo "=============================================="
ls -lh $CAPTURE_DIR
