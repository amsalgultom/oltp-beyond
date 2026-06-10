-- ─────────────────────────────────────────────────────────────────────────────
--  01_kafka_queues.sql
--  Kafka Engine tables — membaca event CDC dari Kafka broker existing.
--  Placeholder KAFKA_BOOTSTRAP_PLACEHOLDER diganti oleh Makefile saat init.
--
--  Tipe kolom datetime mengikuti Debezium time.precision.mode=connect:
--    DATETIME  → Int64 (ms sejak Unix epoch)
--    DATE      → Int32 (hari sejak Unix epoch)
--    TIME      → Int32 (ms sejak tengah malam)
--  __deleted   → String ('true'/'false')
--  __op        → String ('c'=create, 'u'=update, 'd'=delete, 'r'=snapshot)
-- ─────────────────────────────────────────────────────────────────────────────

USE collection;

-- ─── 1. tblAgentLoginStatus ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agent_login_status_queue
(
    markedBy    String,
    state       String,
    datestamp   Nullable(Int32),
    `timestamp` Nullable(Int32),
    extension   Nullable(String),
    ipAddress   Nullable(String),
    __op        LowCardinality(String),
    __ts_ms     Int64,
    __source_ts_ms Int64,
    __deleted   LowCardinality(String)          )
ENGINE = Kafka
SETTINGS
    kafka_broker_list     = 'KAFKA_BOOTSTRAP_PLACEHOLDER',
    kafka_topic_list      = 'dbz.prod_5_smg_mirror_ad.tblAgentLoginStatus',
    kafka_group_name      = 'ch_agent_login_status',
    kafka_format          = 'JSONEachRow',
    kafka_handle_error_mode = 'stream',
    kafka_num_consumers   = 1,
    kafka_max_block_size  = 1000;

-- ─── 2. tblCallDataRecords ────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cdr_queue
(
    uniqueid        String,
    calldate        Nullable(Int64),
    clid            Nullable(String),
    src             Nullable(String),
    dst             Nullable(String),
    dcontext        Nullable(String),
    channel         Nullable(String),
    dstchannel      Nullable(String),
    lastapp         Nullable(String),
    lastdata        Nullable(String),
    duration        Nullable(Int32),
    billsec         Nullable(Int32),
    disposition     Nullable(String),
    amaflags        Nullable(Int32),
    accountcode     Nullable(String),
    uniqueidOri     Nullable(String),
    userfield       Nullable(String),
    contractNo      Nullable(String),
    customerNo      Nullable(String),
    phoneNumber     Nullable(String),
    username        Nullable(String),
    kodeCabang      Nullable(String),
    __op            LowCardinality(String),
    __ts_ms         Int64,
    __source_ts_ms  Int64,
    __deleted       LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list     = 'KAFKA_BOOTSTRAP_PLACEHOLDER',
    kafka_topic_list      = 'dbz.prod_5_smg_mirror_ad.tblCallDataRecords',
    kafka_group_name      = 'ch_cdr',
    kafka_format          = 'JSONEachRow',
    kafka_handle_error_mode = 'stream',
    kafka_num_consumers   = 1,
    kafka_max_block_size  = 5000;

-- ─── 3. tblCollectionResult ───────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS collection_result_queue
(
    uniqueId            Int64,
    noKontrak           Nullable(String),
    callId              Nullable(String),
    agentId             Nullable(String),
    classification      Nullable(String),
    subClassification   Nullable(String),
    ptpAmount           Nullable(Float64),
    ptpDate             Nullable(Int32),
    notes               Nullable(String),
    createdTimeStamp    Nullable(Int64),
    updatedTimeStamp    Nullable(Int64),
    kodeCabang          Nullable(String),
    __op                LowCardinality(String),
    __ts_ms             Int64,
    __source_ts_ms      Int64,
    __deleted           LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list     = 'KAFKA_BOOTSTRAP_PLACEHOLDER',
    kafka_topic_list      = 'dbz.prod_5_smg_mirror_ad.tblCollectionResult',
    kafka_group_name      = 'ch_collection_result',
    kafka_format          = 'JSONEachRow',
    kafka_handle_error_mode = 'stream',
    kafka_num_consumers   = 1,
    kafka_max_block_size  = 1000;

-- ─── 4. tblCollections ────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS collections_queue
(
    collections_id      Int64,
    noKontrak           Nullable(String),
    agentId             Nullable(String),
    callDate            Nullable(Int64),
    classification      Nullable(String),
    subClassification   Nullable(String),
    ptpAmount           Nullable(Float64),
    ptpDate             Nullable(Int32),
    callStatus          Nullable(String),
    notes               Nullable(String),
    createdTimeStamp    Nullable(Int64),
    updatedTimeStamp    Nullable(Int64),
    kodeCabang          Nullable(String),
    overdue             Nullable(Int32),
    __op                LowCardinality(String),
    __ts_ms             Int64,
    __source_ts_ms      Int64,
    __deleted           LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list     = 'KAFKA_BOOTSTRAP_PLACEHOLDER',
    kafka_topic_list      = 'dbz.prod_5_smg_mirror_ad.tblCollections',
    kafka_group_name      = 'ch_collections',
    kafka_format          = 'JSONEachRow',
    kafka_handle_error_mode = 'stream',
    kafka_num_consumers   = 1,
    kafka_max_block_size  = 1000;

-- ─── 5. tblCollectionTask ─────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS collection_task_queue
(
    id                  Int64,
    uniqueId            Nullable(String),
    noKontrak           Nullable(String),
    customerName        Nullable(String),
    phoneNumber         Nullable(String),
    overdue             Nullable(Int32),
    overdueAmount       Nullable(Float64),
    outStdPkk           Nullable(Float64),
    angsuran            Nullable(Float64),
    vehicleType         Nullable(String),
    vehiclePlate        Nullable(String),
    taskType            Nullable(String),
    priority            Nullable(Int32),
    status              Nullable(String),
    assignedAgent       Nullable(String),
    kodeCabang          Nullable(String),
    createdTimestamp    Nullable(Int64),
    updatedTimestamp    Nullable(Int64),
    __op                LowCardinality(String),
    __ts_ms             Int64,
    __source_ts_ms      Int64,
    __deleted           LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list     = 'KAFKA_BOOTSTRAP_PLACEHOLDER',
    kafka_topic_list      = 'dbz.prod_5_smg_mirror_ad.tblCollectionTask',
    kafka_group_name      = 'ch_collection_task',
    kafka_format          = 'JSONEachRow',
    kafka_handle_error_mode = 'stream',
    kafka_num_consumers   = 1,
    kafka_max_block_size  = 1000;

-- ─── 6. tblCustomerId ─────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS customer_id_queue
(
    id                  Int64,
    noKontrak           Nullable(String),
    customerName        Nullable(String),
    phoneNumber         Nullable(String),
    altPhoneNumber      Nullable(String),
    callStatus          Nullable(String),
    priority            Nullable(Int32),
    overdue             Nullable(Int32),
    outStdPkk           Nullable(Float64),
    isPaid              Nullable(Int8),
    paymentDate         Nullable(Int32),
    markedBy            Nullable(String),
    kodeCabang          Nullable(String),
    createdTimestamp    Nullable(Int64),
    markedTimestamp     Nullable(Int64),
    __op                LowCardinality(String),
    __ts_ms             Int64,
    __source_ts_ms      Int64,
    __deleted           LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list     = 'KAFKA_BOOTSTRAP_PLACEHOLDER',
    kafka_topic_list      = 'dbz.prod_5_smg_mirror_ad.tblCustomerId',
    kafka_group_name      = 'ch_customer_id',
    kafka_format          = 'JSONEachRow',
    kafka_handle_error_mode = 'stream',
    kafka_num_consumers   = 1,
    kafka_max_block_size  = 5000;

-- ─── 7. tblUserLogs ───────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_logs_queue
(
    id              Int64,
    username        Nullable(String),
    ipAddress       Nullable(String),
    extension       Nullable(String),
    inTimeStamp     Nullable(Int64),
    outTimeStamp    Nullable(Int64),
    duration        Nullable(Int32),
    kodeCabang      Nullable(String),
    __op            LowCardinality(String),
    __ts_ms         Int64,
    __source_ts_ms  Int64,
    __deleted       LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list     = 'KAFKA_BOOTSTRAP_PLACEHOLDER',
    kafka_topic_list      = 'dbz.prod_5_smg_mirror_ad.tblUserLogs',
    kafka_group_name      = 'ch_user_logs',
    kafka_format          = 'JSONEachRow',
    kafka_handle_error_mode = 'stream',
    kafka_num_consumers   = 1,
    kafka_max_block_size  = 1000;

-- ─── 8. tblUserReleases ───────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS user_releases_queue
(
    id                  Int64,
    hash                String,
    username            Nullable(String),
    releaseDate         Nullable(Int32),
    totalTask           Nullable(Int32),
    totalCalled         Nullable(Int32),
    totalAnswered       Nullable(Int32),
    totalPTP            Nullable(Int32),
    talkTimeSec         Nullable(Int32),
    status              Nullable(String),
    kodeCabang          Nullable(String),
    createdTimestamp    Nullable(Int64),
    updatedTimestamp    Nullable(Int64),
    __op                LowCardinality(String),
    __ts_ms             Int64,
    __source_ts_ms      Int64,
    __deleted           LowCardinality(String)
)
ENGINE = Kafka
SETTINGS
    kafka_broker_list     = 'KAFKA_BOOTSTRAP_PLACEHOLDER',
    kafka_topic_list      = 'dbz.prod_5_smg_mirror_ad.tblUserReleases',
    kafka_group_name      = 'ch_user_releases',
    kafka_format          = 'JSONEachRow',
    kafka_handle_error_mode = 'stream',
    kafka_num_consumers   = 1,
    kafka_max_block_size  = 1000;
