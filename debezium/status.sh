#!/usr/bin/env bash
# status.sh — Cek status Debezium connector dan lag Kafka topic
# Cara pakai: bash debezium/status.sh   (atau: make status)

set -euo pipefail

if [[ -f ".env" ]]; then
  set -o allexport
  # shellcheck disable=SC1091
  source .env
  set +o allexport
fi

CONNECT_HOST="${CONNECT_HOST:-localhost}"
CONNECT_REST_PORT="${CONNECT_REST_PORT:-8083}"
CONNECT_URL="http://${CONNECT_HOST}:${CONNECT_REST_PORT}"
CONNECTOR_NAME="src-collection-mariadb"

# ── Info worker Connect ───────────────────────────────────────────────────────
echo "─── Kafka Connect Worker ─────────────────────────────────────────────"
curl -sf "${CONNECT_URL}/" | python3 -m json.tool 2>/dev/null || \
  echo "ERROR: Tidak bisa konek ke ${CONNECT_URL}"

echo ""

# ── Daftar connector ──────────────────────────────────────────────────────────
echo "─── Semua Connector ──────────────────────────────────────────────────"
curl -sf "${CONNECT_URL}/connectors?expand=status" | \
  python3 -c "
import sys, json
data = json.load(sys.stdin)
for name, info in data.items():
    s = info.get('status', {})
    conn = s.get('connector', {})
    tasks = s.get('tasks', [])
    print(f'  [{name}]')
    print(f'    Connector : {conn.get(\"state\",\"unknown\")}')
    for t in tasks:
        print(f'    Task {t[\"id\"]}   : {t[\"state\"]}')
    if conn.get('state') != 'RUNNING':
        print(f'    Trace     : {conn.get(\"trace\",\"-\")}')
" 2>/dev/null || \
  echo "  (tidak ada connector atau Connect belum siap)"

echo ""

# ── Detail status connector target ───────────────────────────────────────────
echo "─── Detail: ${CONNECTOR_NAME} ────────────────────────────────────────"
DETAIL=$(curl -sf "${CONNECT_URL}/connectors/${CONNECTOR_NAME}/status" 2>/dev/null || echo "{}")
echo "${DETAIL}" | python3 -m json.tool 2>/dev/null || echo "${DETAIL}"

echo ""

# ── Topik yang diharapkan ada ─────────────────────────────────────────────────
echo "─── Topik Debezium (8 tabel) ─────────────────────────────────────────"
TABLES=(
  "tblAgentLoginStatus"
  "tblCallDataRecords"
  "tblCollectionResult"
  "tblCollections"
  "tblCollectionTask"
  "tblCustomerId"
  "tblUserLogs"
  "tblUserReleases"
)
for t in "${TABLES[@]}"; do
  TOPIC="dbz.prod_5_smg_mirror_ad.${t}"
  # Cek via kafka-topics.sh jika tersedia
  if command -v kafka-topics.sh &>/dev/null; then
    EXISTS=$(kafka-topics.sh --bootstrap-server "${KAFKA_BOOTSTRAP}" \
      --describe --topic "${TOPIC}" 2>/dev/null | grep -c "Topic:" || echo "0")
    if [[ "${EXISTS}" -gt 0 ]]; then
      echo "  EXIST  ${TOPIC}"
    else
      echo "  MISSING ${TOPIC}"
    fi
  else
    echo "  ?      ${TOPIC}  (kafka-topics.sh tidak di PATH — cek dari Kafka existing)"
  fi
done

echo ""
echo "─── Topik internal Connect ───────────────────────────────────────────"
INTERNAL_TOPICS=(
  "${CONNECT_CONFIG_TOPIC:-connect-configs-collection}"
  "${CONNECT_OFFSET_TOPIC:-connect-offsets-collection}"
  "${CONNECT_STATUS_TOPIC:-connect-status-collection}"
  "${SCHEMA_HISTORY_TOPIC:-dbz.schema-history.collection}"
)
for t in "${INTERNAL_TOPICS[@]}"; do
  echo "  ${t}"
done
echo "  (verifikasi keberadaan topik di atas di Kafka existing)"
