#!/bin/bash
# =============================================================
# capture_traffic.sh
# =============================================================
# PURPOSE : Capture encrypted TLS traffic to MongoDB
# RUN ON  : node-3 (capture-node)
# USAGE   : bash capture/capture_traffic.sh
# OUTPUT  : /tmp/captures/capture_TIMESTAMP.pcap
# =============================================================

CAPTURE_DIR="/tmp/captures"
mkdir -p $CAPTURE_DIR

# Find network interface
INTERFACE=$(ip route | grep default | awk '{print $5}' | head -1)

echo "=============================================="
echo " TLS Traffic Capture"
echo " Interface : $INTERFACE"
echo " Port      : 27017 (MongoDB)"
echo " Output    : $CAPTURE_DIR"
echo "=============================================="
echo ""
echo " Press Ctrl+C to stop capture"
echo ""

# Start capture
sudo tcpdump -i $INTERFACE \
  port 27017 \
  -w $CAPTURE_DIR/capture_$(date +%Y%m%d_%H%M%S).pcap \
  -v

echo ""
echo "=============================================="
echo " Capture complete!"
ls -lh $CAPTURE_DIR
echo "=============================================="

