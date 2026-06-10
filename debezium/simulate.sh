#!/usr/bin/env bash
# simulate.sh — Demo CDC: insert/update/delete data di MariaDB → check Kafka → ClickHouse
# Cara pakai: bash debezium/simulate.sh
set -euo pipefail

if [[ -f ".env" ]]; then
  set -o allexport
  source .env
  set +o allexport
fi

MARIADB_HOST="${MARIADB_HOST:-mariadb-dev}"
MARIADB_PORT="${MARIADB_PORT:-3306}"
MARIADB_USER="${DEBEZIUM_DB_USER:-root}"
MARIADB_PASSWORD="${DEBEZIUM_DB_PASSWORD:-devroot}"
MARIADB_DB="${MARIADB_DATABASE:-prod_5_smg_mirror_ad}"

KAFKA_BOOTSTRAP="${KAFKA_BOOTSTRAP:-localhost:9092}"
CLICKHOUSE_HOST="${CLICKHOUSE_HOST:-localhost}"
CLICKHOUSE_PORT="${CLICKHOUSE_HTTP_PORT:-8123}"
CLICKHOUSE_USER="${CLICKHOUSE_READONLY_USER:-ch_readonly}"
CLICKHOUSE_PASSWORD="${CLICKHOUSE_READONLY_PASSWORD:-}"

echo "═══════════════════════════════════════════════════════════════════════"
echo "  CDC Simulation — Demo event flow: MariaDB → Kafka → ClickHouse"
echo "═══════════════════════════════════════════════════════════════════════"
echo ""

# ─── Step 1: Insert CDR baru ────────────────────────────────────────────────
echo "[1/5] Insert CDR baru ke MariaDB..."
mysql -h"${MARIADB_HOST}" -P"${MARIADB_PORT}" -u"${MARIADB_USER}" -p"${MARIADB_PASSWORD}" \
  -D "${MARIADB_DB}" \
  -e "INSERT INTO tblCallDataRecords
    (uniqueid, calldate, src, dst, dstchannel, duration, billsec, disposition, accountcode, contractNo, customerNo, phoneNumber, username, kodeCabang)
  VALUES
    (UUID(), NOW(), '101', '0899999999', 'SIP/101-demo', 120, 105, 'ANSWERED', 'SMG', 'KTR-DEMO01', 'CST-DEMO01', '0899999999', 'agent-demo', 'SMG');"

echo "  ✓ CDR inserted"
echo ""

# ─── Step 2: Wait untuk event masuk Kafka ─────────────────────────────────
echo "[2/5] Waiting 5 seconds untuk event mengalir ke Kafka..."
sleep 5
echo "  ✓ Event harus masuk di topik dbz.prod_5_smg_mirror_ad.tblCallDataRecords"
echo ""

# ─── Step 3: Check di Kafka (optional — jika ada kafka CLI) ────────────────
if command -v kafka-console-consumer.sh &>/dev/null; then
  echo "[3/5] Peek Kafka topic (timeout 2s)..."
  timeout 2 kafka-console-consumer.sh --bootstrap-server "${KAFKA_BOOTSTRAP}" \
    --topic "dbz.prod_5_smg_mirror_ad.tblCallDataRecords" \
    --from-beginning --max-messages 1 2>/dev/null || true
  echo ""
else
  echo "[3/5] (Skipped: kafka-console-consumer.sh tidak tersedia)"
  echo ""
fi

# ─── Step 4: Update CDR → trigger CDC ──────────────────────────────────────
echo "[4/5] Update CDR yang baru diinsert..."
mysql -h"${MARIADB_HOST}" -P"${MARIADB_PORT}" -u"${MARIADB_USER}" -p"${MARIADB_PASSWORD}" \
  -D "${MARIADB_DB}" \
  -e "UPDATE tblCallDataRecords
    SET billsec = 110, disposition = 'ANSWERED'
    WHERE src = '101' AND dst = '0899999999' AND accountcode = 'SMG' AND contractNo = 'KTR-DEMO01'
    LIMIT 1;"

echo "  ✓ CDR updated"
echo ""

# ─── Step 5: Check ClickHouse ─────────────────────────────────────────────
echo "[5/5] Query ClickHouse untuk verifikasi..."
sleep 3
echo ""
echo "  ClickHouse — select terbaru dari cdr:"
curl -s \
  -H "X-ClickHouse-User: ${CLICKHOUSE_USER}" \
  -H "X-ClickHouse-Key: ${CLICKHOUSE_PASSWORD}" \
  "http://${CLICKHOUSE_HOST}:${CLICKHOUSE_PORT}/" \
  -d "SELECT uniqueid, calldate, disposition, billsec, _version FROM collection.cdr FINAL WHERE contract_no = 'KTR-DEMO01' ORDER BY _version DESC LIMIT 5 FORMAT Pretty" \
  2>/dev/null || echo "  (Tidak bisa konek ClickHouse — pastikan URL/kredensial di .env benar)"

echo ""
echo "═══════════════════════════════════════════════════════════════════════"
echo "  Demo selesai!"
echo ""
echo "  Checklist verifikasi CDC:"
echo "  ☑ CDR inserted → Kafka event → ClickHouse row"
echo "  ☑ CDR updated → Kafka event → ClickHouse _version naik"
echo "  ☑ ReplacingMergeTree dedup: cdr FINAL hanya row terbaru"
echo "  ☑ cdr_raw append-only: semua versi disimpan (time travel)"
echo ""
echo "  Troubleshoot:"
echo "  - Connector status: make status"
echo "  - ClickHouse tables: SELECT * FROM system.tables WHERE database = 'collection'"
echo "  - Topics: kafka-topics.sh --list"
echo "═══════════════════════════════════════════════════════════════════════"
