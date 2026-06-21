#!/bin/bash
# =============================================================
# 3_generate_certs.sh
# =============================================================
# PURPOSE : Generate TLS certificates for MongoDB
# RUN ON  : node-0
# USAGE   : bash setup/3_generate_certs.sh
# TIME    : ~1 minute
# =============================================================

set -e

REPO_DIR="$(cd "$(dirname $0)/.." && pwd)"
CERT_DIR="$REPO_DIR/kubernetes/mongodb/certs"
mkdir -p $CERT_DIR

echo "=============================================="
echo " [3/4] Generating TLS Certificates"
echo " Output: $CERT_DIR"
echo "=============================================="

# 1. CA private key
echo ""
echo "--> Generating CA private key (4096-bit RSA)..."
openssl genrsa -out $CERT_DIR/ca.key 4096 2>/dev/null
echo "    Done."

# 2. CA certificate
echo ""
echo "--> Generating CA certificate..."
openssl req -new -x509 -days 365 \
  -key $CERT_DIR/ca.key \
  -out $CERT_DIR/ca.crt \
  -subj "/CN=mongodb-ca/O=dissertation" 2>/dev/null
echo "    Done."

# 3. MongoDB server key + CSR
echo ""
echo "--> Generating MongoDB server key and CSR..."
openssl genrsa -out $CERT_DIR/mongo.key 4096 2>/dev/null
openssl req -new \
  -key $CERT_DIR/mongo.key \
  -out $CERT_DIR/mongo.csr \
  -subj "/CN=mongodb/O=dissertation" 2>/dev/null
echo "    Done."

# 4. Sign MongoDB cert with CA
echo ""
echo "--> Signing MongoDB certificate with CA..."
openssl x509 -req -days 365 \
  -in $CERT_DIR/mongo.csr \
  -CA $CERT_DIR/ca.crt \
  -CAkey $CERT_DIR/ca.key \
  -CAcreateserial \
  -out $CERT_DIR/mongo.crt 2>/dev/null
echo "    Done."

# 5. Create combined PEM
echo ""
echo "--> Creating mongo.pem..."
cat $CERT_DIR/mongo.crt $CERT_DIR/mongo.key > $CERT_DIR/mongo.pem
echo "    Done."

echo ""
echo "=============================================="
echo " Certificates generated!"
echo "=============================================="
ls -la $CERT_DIR
echo ""
echo " Next: bash setup/4_deploy_dissertation.sh"
