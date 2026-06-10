-- ─────────────────────────────────────────────────────────────────────────────
--  03_state_tables.sql
--  ReplacingMergeTree(_version, _is_deleted) — current state setiap baris.
--  Query: SELECT * FROM <tabel> FINAL WHERE _is_deleted = 0
--  _version = __ts_ms (epoch ms, makin besar = makin baru)
-- ─────────────────────────────────────────────────────────────────────────────

USE collection;

-- ─── 1. agent_login_status ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agent_login_status
(
    marked_by       String,
    state           LowCardinality(String),
    login_date      Date,
    login_time      Int32,
    extension       String,
    ip_address      String,
    _version        Int64,
    _is_deleted     UInt8
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
PARTITION BY tuple()
ORDER BY (marked_by)
SETTINGS index_granularity = 8192;

-- ─── 2. cdr ───────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cdr
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
    _version        Int64,
    _is_deleted     UInt8
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
PARTITION BY toYYYYMM(toDate(calldate))
ORDER BY (uniqueid, calldate)
SETTINGS index_granularity = 8192;

-- ─── 3. collection_result ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS collection_result
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
    _version            Int64,
    _is_deleted         UInt8
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
PARTITION BY toYYYYMM(toDate(created_ts))
ORDER BY (unique_id)
SETTINGS index_granularity = 8192;

-- ─── 4. collections ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS collections
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
    _version            Int64,
    _is_deleted         UInt8
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
PARTITION BY toYYYYMM(toDate(created_ts))
ORDER BY (collections_id)
SETTINGS index_granularity = 8192;

-- ─── 5. collection_task ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS collection_task
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
    _version        Int64,
    _is_deleted     UInt8
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
PARTITION BY toYYYYMM(toDate(created_ts))
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ─── 6. customer_id ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customer_id
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
    _version        Int64,
    _is_deleted     UInt8
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
PARTITION BY toYYYYMM(toDate(created_ts))
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ─── 7. user_logs ────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_logs
(
    id          Int64,
    username    LowCardinality(String),
    ip_address  String,
    extension   String,
    in_ts       DateTime64(3),
    out_ts      DateTime64(3),
    duration    Int32,
    kode_cabang LowCardinality(String),
    _version    Int64,
    _is_deleted UInt8
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
PARTITION BY toYYYYMM(toDate(in_ts))
ORDER BY (id)
SETTINGS index_granularity = 8192;

-- ─── 8. user_releases ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_releases
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
    _version        Int64,
    _is_deleted     UInt8
)
ENGINE = ReplacingMergeTree(_version, _is_deleted)
PARTITION BY toYYYYMM(release_date)
ORDER BY (id, hash)
SETTINGS index_granularity = 8192;
