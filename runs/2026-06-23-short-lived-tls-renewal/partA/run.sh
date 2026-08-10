#!/usr/bin/env bash
# Part A — deterministic short-lived-cert handshake-break demo (no network, local CA)
export MSYS_NO_PATHCONV=1
set -e
cd "$(dirname "$0")"
echo "=== openssl $(openssl version) ==="

# 1) Local root CA (EC P-256)
openssl ecparam -name prime256v1 -genkey -noout -out ca.key
openssl req -x509 -new -nodes -key ca.key -sha256 -days 1 \
  -subj "/CN=Firsthand Local Root" -out ca.crt
echo "[CA] 1-day local root created"

# 2) Leaf key + CSR
openssl ecparam -name prime256v1 -genkey -noout -out leaf.key
openssl req -new -key leaf.key -subj "/CN=localhost" -out leaf.csr
cat > leaf.ext <<'EOF'
subjectAltName=DNS:localhost,IP:127.0.0.1
keyUsage=digitalSignature
extendedKeyUsage=serverAuth
EOF

# 3) Sign a SHORT-LIVED leaf: now-5s .. now+40s
NB=$(date -u -d "now -5 seconds" +%Y%m%d%H%M%SZ)
NA=$(date -u -d "now +40 seconds" +%Y%m%d%H%M%SZ)
openssl x509 -req -in leaf.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -not_before "$NB" -not_after "$NA" -extfile leaf.ext -sha256 -out leaf.crt
echo "[LEAF] short-lived cert issued"
SD=$(openssl x509 -in leaf.crt -noout -startdate | cut -d= -f2)
ED=$(openssl x509 -in leaf.crt -noout -enddate  | cut -d= -f2)
LIFE=$(( $(date -u -d "$ED" +%s) - $(date -u -d "$SD" +%s) ))
echo "  NotBefore: $SD"
echo "  NotAfter : $ED"
echo "  Lifetime : ${LIFE}s (tiny on purpose, to compress the renewal cycle into one run)"
echo "READY_NA_EPOCH=$(date -u -d "$ED" +%s)"
