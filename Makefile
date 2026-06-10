# ─────────────────────────────────────────────────────────────────────────────
#  Makefile — CDC Collection Analytics Pipeline
#  Komponen BARU: Kafka Connect/Debezium, ClickHouse, Next.js
#  Kafka & MariaDB sudah ada di server lain; tidak di-deploy ulang di sini.
# ─────────────────────────────────────────────────────────────────────────────

include .env
export

COMPOSE         := docker compose
CONNECT_URL     := http://$(CONNECT_HOST):$(CONNECT_REST_PORT)
CONNECTOR_NAME  := src-collection-mariadb

.DEFAULT_GOAL := help

# ─── Help ──────────────────────────────────────────────────────────────────────
.PHONY: help
help: ## Tampilkan daftar perintah ini
	@echo ""
	@echo "  CDC Collection Analytics — Perintah Make"
	@echo "  ─────────────────────────────────────────────────────────────────"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) \
	  | awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-20s\033[0m %s\n", $$1, $$2}'
	@echo ""
	@echo "  Profil Docker Compose:"
	@echo "    default : connect + clickhouse + nextjs (konek ke Kafka & MariaDB existing)"
	@echo "    dev     : + MariaDB stand-in lokal untuk uji tanpa menyentuh prod"
	@echo ""
	@echo "  Contoh alur:"
	@echo "    make up           # nyalakan komponen baru"
	@echo "    make register     # daftarkan Debezium connector"
	@echo "    make status       # cek status connector + row ClickHouse"
	@echo "    make verify       # smoke test end-to-end"
	@echo ""

# ─── Docker Compose ────────────────────────────────────────────────────────────
.PHONY: up
up: ## Nyalakan connect + clickhouse + nextjs (konek ke infra existing)
	$(COMPOSE) up -d --build
	@echo ">>> Tunggu ClickHouse & Connect siap..."
	@sleep 10
	@$(MAKE) init-clickhouse

.PHONY: up-dev
up-dev: ## Nyalakan semua + MariaDB stand-in lokal (profile dev)
	$(COMPOSE) --profile dev up -d --build
	@echo ">>> Tunggu MariaDB stand-in siap..."
	@sleep 15
	@$(MAKE) seed-dev
	@sleep 5
	@$(MAKE) init-clickhouse

.PHONY: down
down: ## Matikan semua service, pertahankan volume
	$(COMPOSE) --profile dev down

.PHONY: down-v
down-v: ## Matikan semua service DAN hapus volume (data hilang!)
	@echo "PERINGATAN: Semua data ClickHouse & Connect offset akan dihapus."
	@read -p "Lanjut? [y/N] " confirm && [ "$$confirm" = "y" ]
	$(COMPOSE) --profile dev down -v

.PHONY: logs
logs: ## Tampilkan log semua service (Ctrl+C untuk keluar)
	$(COMPOSE) --profile dev logs -f

.PHONY: logs-connect
logs-connect: ## Tampilkan log Kafka Connect saja
	$(COMPOSE) logs -f connect

.PHONY: logs-ch
logs-ch: ## Tampilkan log ClickHouse saja
	$(COMPOSE) logs -f clickhouse

# ─── ClickHouse init ──────────────────────────────────────────────────────────
.PHONY: init-clickhouse
init-clickhouse: ## Jalankan semua DDL ClickHouse (00–08)
	@echo ">>> Inisialisasi skema ClickHouse..."
	@for f in clickhouse/0*.sql; do \
	  echo "  Applying $$f..."; \
	  sed "s|KAFKA_BOOTSTRAP_PLACEHOLDER|$(KAFKA_BOOTSTRAP)|g; \
	       s|CLICKHOUSE_DATABASE_PLACEHOLDER|$(CLICKHOUSE_DATABASE)|g; \
	       s|CLICKHOUSE_READONLY_PASSWORD_PLACEHOLDER|$(CLICKHOUSE_READONLY_PASSWORD)|g" "$$f" | \
	  docker compose exec -T clickhouse clickhouse-client \
	    --user "$(CLICKHOUSE_ADMIN_USER)" \
	    --password "$(CLICKHOUSE_ADMIN_PASSWORD)" \
	    --multiquery; \
	done
	@echo ">>> ClickHouse siap."

# ─── Debezium Connector ────────────────────────────────────────────────────────
.PHONY: register
register: ## Daftarkan Debezium connector ke Kafka Connect
	@echo ">>> Mendaftarkan connector $(CONNECTOR_NAME)..."
	bash debezium/register.sh
	@sleep 3
	@$(MAKE) status

.PHONY: status
status: ## Cek status connector + lag + jumlah baris ClickHouse
	@echo "─── Connector Status ────────────────────────────────────────────"
	bash debezium/status.sh
	@echo ""
	@echo "─── ClickHouse Row Counts ───────────────────────────────────────"
	@docker compose exec -T clickhouse clickhouse-client \
	  --user $(CLICKHOUSE_READONLY_USER) \
	  --password $(CLICKHOUSE_READONLY_PASSWORD) \
	  --database $(CLICKHOUSE_DATABASE) \
	  --query "SELECT name, total_rows FROM system.tables WHERE database='$(CLICKHOUSE_DATABASE)' AND engine NOT IN ('View','MaterializedView','Kafka') ORDER BY name" \
	  2>/dev/null || echo "  (ClickHouse belum siap atau database belum ada)"

.PHONY: delete-connector
delete-connector: ## Hapus connector (stop CDC)
	@echo ">>> Menghapus connector $(CONNECTOR_NAME)..."
	curl -s -X DELETE $(CONNECT_URL)/connectors/$(CONNECTOR_NAME) | cat
	@echo ""

.PHONY: pause-connector
pause-connector: ## Pause connector sementara
	curl -s -X PUT $(CONNECT_URL)/connectors/$(CONNECTOR_NAME)/pause | cat

.PHONY: resume-connector
resume-connector: ## Resume connector yang di-pause
	curl -s -X PUT $(CONNECT_URL)/connectors/$(CONNECTOR_NAME)/resume | cat

# ─── Dev helpers ──────────────────────────────────────────────────────────────
.PHONY: seed-dev
seed-dev: ## Isi data dummy ke MariaDB stand-in (hanya dev)
	@echo ">>> Seeding MariaDB stand-in..."
	docker compose --profile dev exec -T mariadb-dev \
	  mysql -uroot -p$(DEV_MARIADB_ROOT_PASSWORD) $(DEV_MARIADB_DATABASE) \
	  < source/seed.dev.sql
	@echo ">>> Seed selesai."

.PHONY: prereq
prereq: ## Jalankan cek prasyarat MariaDB (terhubung ke server existing via .env)
	@echo ">>> Mengecek prasyarat MariaDB di $(MARIADB_HOST):$(MARIADB_PORT)..."
	@mysql -h$(MARIADB_HOST) -P$(MARIADB_PORT) -u$(DEBEZIUM_DB_USER) -p$(DEBEZIUM_DB_PASSWORD) \
	  < source/check-source-prereq.sql || \
	  echo "GAGAL: Tidak bisa koneksi. Pastikan host, port, dan kredensial di .env sudah benar."

# ─── Smoke test ───────────────────────────────────────────────────────────────
.PHONY: verify
verify: ## Smoke test end-to-end: connector running + data mengalir ke ClickHouse
	@echo "─── Smoke Test End-to-End ────────────────────────────────────────"
	@echo ""
	@echo "[1/3] Status connector:"
	@curl -s $(CONNECT_URL)/connectors/$(CONNECTOR_NAME)/status \
	  | python3 -c "import sys,json; d=json.load(sys.stdin); \
	    print('  Connector:', d['connector']['state']); \
	    [print('  Task', t['id'], ':', t['state']) for t in d['tasks']]" \
	  2>/dev/null || curl -s $(CONNECT_URL)/connectors/$(CONNECTOR_NAME)/status
	@echo ""
	@echo "[2/3] Row counts di ClickHouse (state tables):"
	@docker compose exec -T clickhouse clickhouse-client \
	  --user $(CLICKHOUSE_READONLY_USER) \
	  --password $(CLICKHOUSE_READONLY_PASSWORD) \
	  --database $(CLICKHOUSE_DATABASE) \
	  --query "SELECT 'agent_login_status' t, count() n FROM agent_login_status FINAL WHERE _is_deleted=0 \
	    UNION ALL SELECT 'cdr', count() FROM cdr FINAL WHERE _is_deleted=0 \
	    UNION ALL SELECT 'collection_result', count() FROM collection_result FINAL WHERE _is_deleted=0 \
	    UNION ALL SELECT 'collection_task', count() FROM collection_task FINAL WHERE _is_deleted=0 \
	    UNION ALL SELECT 'customer_id', count() FROM customer_id FINAL WHERE _is_deleted=0 \
	    UNION ALL SELECT 'user_logs', count() FROM user_logs FINAL WHERE _is_deleted=0 \
	    UNION ALL SELECT 'user_releases', count() FROM user_releases FINAL WHERE _is_deleted=0 \
	    FORMAT PrettyCompact" 2>/dev/null || echo "  (Tabel belum ada atau CDC belum mengalir)"
	@echo ""
	@echo "[3/3] Next.js dashboard:"
	@curl -s -o /dev/null -w "  HTTP %{http_code} — http://localhost:3000\n" http://localhost:3000/ \
	  2>/dev/null || echo "  (Next.js belum jalan — jalankan: make up)"
	@echo ""
	@echo "─── Selesai ─────────────────────────────────────────────────────"

# ─── Utilitas ─────────────────────────────────────────────────────────────────
.PHONY: ps
ps: ## Lihat status container
	$(COMPOSE) --profile dev ps

.PHONY: topics
topics: ## Daftar topik Kafka yang dibuat Debezium (butuh kafka-topics di PATH)
	@echo ">>> Topik dengan prefix 'dbz.':"
	@kafka-topics.sh --bootstrap-server $(KAFKA_BOOTSTRAP) --list 2>/dev/null \
	  | grep "^dbz\." || echo "  (kafka-topics.sh tidak ditemukan di PATH — cek dari Kafka existing)"
