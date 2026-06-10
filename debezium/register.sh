#!/usr/bin/env bash
# register.sh — Daftarkan Debezium connector ke Kafka Connect REST API
# Cara pakai: bash debezium/register.sh   (atau: make register)
set -euo pipefail

if [[ -f ".env" ]]; then
  set -o allexport
  source .env
  set +o allexport
fi

CONNECT_HOST="${CONNECT_HOST:-localhost}"
CONNECT_REST_PORT="${CONNECT_REST_PORT:-8083}"
CONNECT_URL="http://${CONNECT_HOST}:${CONNECT_REST_PORT}"
CONNECTOR_NAME="src-collection-mariadb"

echo ">>> Menunggu Kafka Connect siap di ${CONNECT_URL} ..."
for i in $(seq 1 30); do
  if curl -sf "${CONNECT_URL}/" > /dev/null 2>&1; then
    echo "    Connect siap (percobaan ${i})."
    break
  fi
  if [ "${i}" -eq 30 ]; then
    echo "ERROR: Kafka Connect tidak merespons setelah 150 detik."
    exit 1
  fi
  echo "    Percobaan ${i}/30 — tunggu 5 detik..."
  sleep 5
done

# Substitusi env vars ke dalam template connector JSON
PAYLOAD=$(envsubst < debezium/connector-mariadb.json)

HTTP_STATUS=$(curl -sf -o /dev/null -w "%{http_code}" \
  "${CONNECT_URL}/connectors/${CONNECTOR_NAME}" 2>/dev/null || echo "000")

if [[ "${HTTP_STATUS}" == "200" ]]; then
  echo ">>> Connector '${CONNECTOR_NAME}' sudah ada. Memperbarui konfigurasi..."
  CONFIG=$(echo "${PAYLOAD}" | python3 -c "import sys,json; d=json.load(sys.stdin); print(json.dumps(d['config']))")
  RESPONSE=$(curl -s -X PUT \
    -H "Content-Type: application/json" \
    --data "${CONFIG}" \
    "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/config")
else
  echo ">>> Mendaftarkan connector baru '${CONNECTOR_NAME}'..."
  RESPONSE=$(curl -s -X POST \
    -H "Content-Type: application/json" \
    --data "${PAYLOAD}" \
    "${CONNECT_URL}/connectors")
fi

echo "${RESPONSE}" | python3 -m json.tool 2>/dev/null || echo "${RESPONSE}"
echo ""
echo ">>> Menunggu 3 detik lalu cek status..."
sleep 3
bash debezium/status.sh
