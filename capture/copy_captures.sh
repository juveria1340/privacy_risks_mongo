#!/bin/bash
# =============================================================
# copy_captures.sh
# =============================================================
# PURPOSE : Print commands to copy pcap files to laptop
# RUN ON  : node-1
# USAGE   : bash capture/copy_captures.sh
# =============================================================

CAPTURE_DIR="/tmp/captures"

echo "=============================================="
echo " Capture Files Summary"
echo "=============================================="
ls -lh $CAPTURE_DIR
echo ""
echo "=============================================="
echo " Copy to your laptop using this command:"
echo " (Run on your Windows PowerShell)"
echo "=============================================="
echo ""
echo "scp -i C:\Users\juver\.ssh\id_ed25519 \\"

NODE1_HOST=$(hostname -f)
for file in $CAPTURE_DIR/*.pcap; do
  echo "  Juveria@${NODE1_HOST}:${file} \\"
done

echo "  C:\Users\juver\Desktop\privacy_risks_mongo\data\raw\"
echo ""
echo "=============================================="
