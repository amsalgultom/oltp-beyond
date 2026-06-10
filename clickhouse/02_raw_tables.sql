-- ─────────────────────────────────────────────────────────────────────────────
--  02_raw_tables.sql
--  Tabel *_raw — append-only, simpan SEMUA versi event CDC.
--  Dipakai untuk Time Travel (as-of query) dan audit trail.
--
--  Konversi waktu dari Debezium (time.precision.mode=connect):
--    Int64 ms  → DateTime64(3) via toDateTime64(val/1000, 3)
--    Int32 hari → Date         via toDate(val)
-- ─────────────────────────────────────────────────────────────────────────────

USE collection;

-- ─── 1. agent_login_status_raw ────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agent_login_status_raw
(
    marked_by       String,
    state           LowCardinality(String),
    login_date      Date,
    login_time      Int32,
    extension       String,
    ip_address      String,
    _op             LowCardinality(String),
    _ts_ms          Int64,
    _source_ts_ms   Int64,
    _is_deleted     UInt8,
    _ingested_at    DateTime64(3) DEFAULT now64(3)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(login_date)
ORDER BY (marked_by, _ts_ms)
SETTINGS index_granularity = 8192;

-- ─── 2. cdr_raw ───────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cdr_raw
(
    uniqueid        String,
    calldate        DateTime64(3),
    src             String,
    dst             String,
    dstchannel      String,
    duration        Int32,
    billsec         Int32,
    disposition     LowCardinality(String),
    accountcode     String,
    contract_no     String,
    customer_no     String,
    phone_number    String,
    username        LowCardinality(String),
    kode_cabang     LowCardinality(String),
    _op             LowCardinality(String),
    _ts_ms          Int64,
    _source_ts_ms   Int64,
    _is_deleted     UInt8,
    _ingested_at    DateTime64(3) DEFAULT now64(3)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(toDate(calldate))
ORDER BY (uniqueid, calldate, _ts_ms)
SETTINGS index_granularity = 8192;

-- ─── 3. collection_result_raw ─────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS collection_result_raw
(
    unique_id           Int64,
    no_kontrak          String,
    call_id             String,
    agent_id            String,
    classification      LowCardinality(String),
    sub_classification  String,
    ptp_amount          Float64,
    ptp_date            Date,
    notes               String,
    created_ts          DateTime64(3),
    updated_ts          DateTime64(3),
    kode_cabang         LowCardinality(String),
    _op                 LowCardinality(String),
    _ts_ms              Int64,
    _source_ts_ms       Int64,
    _is_deleted         UInt8,
    _ingested_at        DateTime64(3) DEFAULT now64(3)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(toDate(created_ts))
ORDER BY (unique_id, _ts_ms)
SETTINGS index_granularity = 8192;

-- ─── 4. collections_raw ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS collections_raw
(
    collections_id      Int64,
    no_kontrak          String,
    agent_id            String,
    call_date           DateTime64(3),
    classification      LowCardinality(String),
    sub_classification  String,
    ptp_amount          Float64,
    ptp_date            Date,
    call_status         LowCardinality(String),
    notes               String,
    created_ts          DateTime64(3),
    updated_ts          DateTime64(3),
    kode_cabang         LowCardinality(String),
    overdue             Int32,
    _op                 LowCardinality(String),
    _ts_ms              Int64,
    _source_ts_ms       Int64,
    _is_deleted         UInt8,
    _ingested_at        DateTime64(3) DEFAULT now64(3)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(toDate(created_ts))
ORDER BY (collections_id, _ts_ms)
SETTINGS index_granularity = 8192;

-- ─── 5. collection_task_raw ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS collection_task_raw
(
    id              Int64,
    unique_id       String,
    no_kontrak      String,
    customer_name   String,
    phone_number    String,
    overdue         Int32,
    overdue_amount  Float64,
    out_std_pkk     Float64,
    angsuran        Float64,
    vehicle_type    LowCardinality(String),
    vehicle_plate   String,
    task_type       LowCardinality(String),
    priority        Int32,
    status          LowCardinality(String),
    assigned_agent  String,
    kode_cabang     LowCardinality(String),
    created_ts      DateTime64(3),
    updated_ts      DateTime64(3),
    _op             LowCardinality(String),
    _ts_ms          Int64,
    _source_ts_ms   Int64,
    _is_deleted     UInt8,
    _ingested_at    DateTime64(3) DEFAULT now64(3)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(toDate(created_ts))
ORDER BY (id, _ts_ms)
SETTINGS index_granularity = 8192;

-- ─── 6. customer_id_raw ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customer_id_raw
(
    id              Int64,
    no_kontrak      String,
    customer_name   String,
    phone_number    String,
    alt_phone       String,
    call_status     LowCardinality(String),
    priority        Int32,
    overdue         Int32,
    out_std_pkk     Float64,
    is_paid         UInt8,
    payment_date    Date,
    marked_by       String,
    kode_cabang     LowCardinality(String),
    created_ts      DateTime64(3),
    marked_ts       DateTime64(3),
    _op             LowCardinality(String),
    _ts_ms          Int64,
    _source_ts_ms   Int64,
    _is_deleted     UInt8,
    _ingested_at    DateTime64(3) DEFAULT now64(3)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(toDate(created_ts))
ORDER BY (id, _ts_ms)
SETTINGS index_granularity = 8192;

-- ─── 7. user_logs_raw ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_logs_raw
(
    id          Int64,
    username    LowCardinality(String),
    ip_address  String,
    extension   String,
    in_ts       DateTime64(3),
    out_ts      DateTime64(3),
    duration    Int32,
    kode_cabang LowCardinality(String),
    _op         LowCardinality(String),
    _ts_ms      Int64,
    _source_ts_ms Int64,
    _is_deleted UInt8,
    _ingested_at DateTime64(3) DEFAULT now64(3)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(toDate(in_ts))
ORDER BY (id, _ts_ms)
SETTINGS index_granularity = 8192;

-- ─── 8. user_releases_raw ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_releases_raw
(
    id              Int64,
    hash            String,
    username        LowCardinality(String),
    release_date    Date,
    total_task      Int32,
    total_called    Int32,
    total_answered  Int32,
    total_ptp       Int32,
    talk_time_sec   Int32,
    status          LowCardinality(String),
    kode_cabang     LowCardinality(String),
    created_ts      DateTime64(3),
    updated_ts      DateTime64(3),
    _op             LowCardinality(String),
    _ts_ms          Int64,
    _source_ts_ms   Int64,
    _is_deleted     UInt8,
    _ingested_at    DateTime64(3) DEFAULT now64(3)
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(release_date)
ORDER BY (id, hash, _ts_ms)
SETTINGS index_granularity = 8192;
