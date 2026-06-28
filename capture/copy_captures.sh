#!/bin/bash
# =============================================================
# copy_captures.sh
# =============================================================
# PURPOSE : Show pcap files and scp commands to copy to laptop
# RUN ON  : node-1
# USAGE   : bash capture/copy_captures.sh
# =============================================================

CAPTURE_DIR="/tmp/captures"

echo "=============================================="
echo " Capture Files Summary"
echo "=============================================="
echo ""
echo "Files on node-1:"
ls -lh $CAPTURE_DIR/*.pcap 2>/dev/null || echo "No pcap files found!"
echo ""

# Show packet counts
echo "Packet counts per file:"
for f in $CAPTURE_DIR/*.pcap; do
  if [ -f "$f" ]; then
    count=$(sudo tcpdump -r $f 2>/dev/null | wc -l)
    size=$(ls -lh $f | awk '{print $5}')
    name=$(basename $f)
    echo "  $name: $count packets ($size)"
  fi
done

echo ""
echo "=============================================="
echo " Copy to Windows laptop"
echo " Run these commands in PowerShell:"
echo "=============================================="
echo ""

NODE1_HOST=$(hostname -f)

echo "# Create local directory first:"
echo "mkdir C:\Users\juver\Desktop\privacy_risks_mongo\data\raw"
echo ""
echo "# Copy each pcap file:"
for file in $CAPTURE_DIR/*.pcap; do
  if [ -f "$file" ]; then
    name=$(basename $file)
    echo "scp -i C:\Users\juver\.ssh\id_ed25519 Juveria@${NODE1_HOST}:${file} C:\Users\juver\Desktop\privacy_risks_mongo\data\raw\${name}"
  fi
done

echo ""
echo "# Or copy ALL at once:"
echo "scp -i C:\Users\juver\.ssh\id_ed25519 Juveria@${NODE1_HOST}:/tmp/captures/*.pcap C:\Users\juver\Desktop\privacy_risks_mongo\data\raw\"
echo ""
echo "=============================================="
echo " View pcap files on Windows using Wireshark:"
echo " https://www.wireshark.org/download.html"
echo "=============================================="
