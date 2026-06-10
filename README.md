# CDC Collection Analytics

Pipeline CDC real-time: **MariaDB (OLTP) → Debezium → Kafka → ClickHouse (OLAP) → Next.js Dashboard**

Domain: sistem call center penagihan (desk collection) multifinance.

## Arsitektur

```
  SERVER EXISTING                       SISTEM INI (Docker Compose)
  ┌───────────────┐  binlog (ROW)    ┌─────────────────────────────┐
  │ MariaDB 5.5   │────read-only────▶│ Kafka Connect + Debezium    │
  │ (OLTP, prod)  │                  │   8 tabel, snapshot_only    │
  └───────────────┘                  └──────────────┬──────────────┘
                                                     │ produce
  ┌───────────────┐                                  ▼
  │ Apache Kafka  │◀─────────────── topics per tabel ──────────────
  │ (existing)    │──────consume───▶
  └───────────────┘                 ┌─────────────────────────────┐
                                    │ ClickHouse (OLAP)           │
                                    │  *_queue  Kafka engine      │
                                    │  *_raw    append (history)  │
                                    │  *        ReplacingMergeTree│
                                    │  mv_*     pre-aggregations  │
                                    └──────────────┬──────────────┘
                                                   │ HTTP :8123
                                                   ▼
                                    ┌─────────────────────────────┐
                                    │ Next.js Dashboard           │
                                    │  Streaming · Funnel         │
                                    │  Distribution · Pre-Agg     │
                                    │  Time Travel                │
                                    └─────────────────────────────┘
```

## Tabel yang di-capture (8 tabel)

| Tabel | Peran |
|-------|-------|
| `tblAgentLoginStatus` | Status login agent (state) |
| `tblCallDataRecords` | CDR / log panggilan (fakta utama) |
| `tblCollectionResult` | Hasil call (PTP, RPC, alasan) |
| `tblCollections` | Snapshot collections |
| `tblCollectionTask` | Task/penugasan kontrak |
| `tblCustomerId` | Antrian/status panggilan per kontrak |
| `tblUserLogs` | Log login/logout agent |
| `tblUserReleases` | Rilis/penugasan user |

> `tblCustomerId_copy` **dikecualikan** — tidak masuk pipeline.

## Prasyarat

- Docker & Docker Compose v2
- Akses ke **MariaDB existing** (host, port, user `debezium` dengan grant CDC)
- Akses ke **Kafka existing** (bootstrap server)
- MariaDB dengan `binlog_format=ROW` aktif

## Setup cepat

```bash
# 1. Copy dan isi variabel
cp .env.example .env
# Edit .env: isi MARIADB_HOST, KAFKA_BOOTSTRAP, password, dll.

# 2. Cek prasyarat server MariaDB existing (jalankan dari mesin yang bisa konek)
make prereq
# Atau langsung: mysql -h<host> -u debezium -p < source/check-source-prereq.sql

# 3. Nyalakan komponen baru
make up

# 4. Daftarkan Debezium connector
make register

# 5. Cek status
make status

# 6. Buka dashboard
open http://localhost:3000
```

### Mode dev (uji lokal tanpa prod)

```bash
# Nyalakan semua + MariaDB stand-in lokal (port 3307)
make up-dev

# Ubah .env sementara untuk dev:
#   MARIADB_HOST=mariadb-dev
#   MARIADB_PORT=3307

make register
make verify
```

## Perintah Make

```
make help            Tampilkan semua perintah
make up              Nyalakan connect + clickhouse + nextjs
make up-dev          + MariaDB stand-in (profile dev)
make down            Matikan (pertahankan volume)
make register        Daftarkan Debezium connector
make status          Status connector + row counts ClickHouse
make verify          Smoke test end-to-end
make prereq          Cek prasyarat MariaDB existing
make seed-dev        Isi data dummy ke MariaDB stand-in
make logs            Log semua service
make logs-connect    Log Kafka Connect
make logs-ch         Log ClickHouse
```

## Struktur repo

```
.
├── .env.example           # template variabel koneksi
├── docker-compose.yml     # komponen baru + profil dev
├── Makefile               # perintah operasional
├── source/
│   ├── table.sql          # DDL referensi 8 tabel sumber
│   ├── check-source-prereq.sql   # validasi binlog & grant
│   └── seed.dev.sql       # data dummy untuk dev
├── debezium/
│   ├── connector-mariadb.json    # konfigurasi connector
│   ├── register.sh               # POST ke Connect REST API
│   └── status.sh                 # cek status & lag
├── clickhouse/
│   ├── 00_database.sql    # buat database + user
│   ├── 01_kafka_queues.sql
│   ├── 02_raw_tables.sql
│   ├── 03_state_tables.sql
│   ├── 04_mv_ingest.sql
│   ├── 05_dim_fact_views.sql
│   ├── 06_preagg.sql
│   ├── 07_projections.sql
│   ├── 08_users.sql
│   └── queries/           # SQL analitik 5 fitur
├── nextjs/                # dashboard Next.js 15
└── docs/
    ├── runbook.md
    └── data-dictionary.md
```

## Keamanan

- Kredensial hanya di `.env` — **jangan commit `.env` asli**
- User `debezium` di MariaDB: SELECT + RELOAD + REPLICATION SLAVE/CLIENT saja
- User `ch_readonly` di ClickHouse: SELECT saja, dipakai Next.js
- ClickHouse hanya diakses dari server-side Next.js (Route Handlers)

## Troubleshooting

Lihat [docs/runbook.md](docs/runbook.md).
