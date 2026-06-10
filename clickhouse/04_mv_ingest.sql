-- ─────────────────────────────────────────────────────────────────────────────
--  04_mv_ingest.sql
--  Materialized Views: queue → raw (append-only history) + queue → state (FINAL).
--  Konversi tipe dan parsing datetime dari format Debezium.
--
--  Semua kolom Nullable dari *_queue dibungkus coalesce()/ifNull() agar tidak
--  error "Cannot convert NULL value to non-Nullable type" saat data produksi
--  punya kolom NULL (kolom tujuan di *_raw/*_state non-Nullable).
-- ─────────────────────────────────────────────────────────────────────────────

USE collection;

-- Helper function: parse datetime dari Unix ms
-- toDateTime64(ms/1000, 3) → DateTime64(3, 'UTC')

-- ─── 1. MV: agent_login_status_queue → agent_login_status_raw ────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_agent_login_status_raw TO agent_login_status_raw AS
SELECT
    markedBy                                    AS marked_by,
    state                                       AS state,
    toDate(coalesce(datestamp, 0))              AS login_date,
    coalesce(timestamp, 0)                      AS login_time,
    coalesce(extension, '')                     AS extension,
    coalesce(ipAddress, '')                     AS ip_address,
    __op                                        AS _op,
    __ts_ms                                     AS _ts_ms,
    __source_ts_ms                              AS _source_ts_ms,
    if(__deleted = 'true', 1, 0)                AS _is_deleted
FROM agent_login_status_queue;

-- ─── 1b. MV: agent_login_status_queue → agent_login_status (state) ──────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_agent_login_status_state TO agent_login_status AS
SELECT
    markedBy                                    AS marked_by,
    state                                       AS state,
    toDate(coalesce(datestamp, 0))              AS login_date,
    coalesce(timestamp, 0)                      AS login_time,
    coalesce(extension, '')                     AS extension,
    coalesce(ipAddress, '')                     AS ip_address,
    __ts_ms                                     AS _version,
    if(__deleted = 'true', 1, 0)                AS _is_deleted
FROM agent_login_status_queue;

-- ─── 2. MV: cdr_queue → cdr_raw ───────────────────────────────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_cdr_raw TO cdr_raw AS
SELECT
    uniqueid                                    AS uniqueid,
    toDateTime64(coalesce(calldate, 0)/1000, 3) AS calldate,
    coalesce(src, '')                           AS src,
    coalesce(dst, '')                           AS dst,
    coalesce(dstchannel, '')                    AS dstchannel,
    coalesce(duration, 0)                       AS duration,
    coalesce(billsec, 0)                        AS billsec,
    coalesce(disposition, '')                   AS disposition,
    coalesce(accountcode, '')                   AS accountcode,
    coalesce(contractNo, '')                    AS contract_no,
    coalesce(customerNo, '')                    AS customer_no,
    coalesce(phoneNumber, '')                   AS phone_number,
    coalesce(username, '')                      AS username,
    coalesce(kodeCabang, '')                    AS kode_cabang,
    __op                                        AS _op,
    __ts_ms                                     AS _ts_ms,
    __source_ts_ms                              AS _source_ts_ms,
    if(__deleted = 'true', 1, 0)                AS _is_deleted
FROM cdr_queue;

-- ─── 2b. MV: cdr_queue → cdr (state) ───────────────────────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_cdr_state TO cdr AS
SELECT
    uniqueid                                    AS uniqueid,
    toDateTime64(coalesce(calldate, 0)/1000, 3) AS calldate,
    coalesce(src, '')                           AS src,
    coalesce(dst, '')                           AS dst,
    coalesce(dstchannel, '')                    AS dstchannel,
    coalesce(duration, 0)                       AS duration,
    coalesce(billsec, 0)                        AS billsec,
    coalesce(disposition, '')                   AS disposition,
    coalesce(accountcode, '')                   AS accountcode,
    coalesce(contractNo, '')                    AS contract_no,
    coalesce(customerNo, '')                    AS customer_no,
    coalesce(phoneNumber, '')                   AS phone_number,
    coalesce(username, '')                      AS username,
    coalesce(kodeCabang, '')                    AS kode_cabang,
    __ts_ms                                     AS _version,
    if(__deleted = 'true', 1, 0)                AS _is_deleted
FROM cdr_queue;

-- ─── 3. MV: collection_result_queue → collection_result_raw ──────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_collection_result_raw TO collection_result_raw AS
SELECT
    uniqueId                                            AS unique_id,
    coalesce(noKontrak, '')                             AS no_kontrak,
    coalesce(callId, '')                                AS call_id,
    coalesce(agentId, '')                               AS agent_id,
    coalesce(classification, '')                        AS classification,
    coalesce(subClassification, '')                     AS sub_classification,
    coalesce(ptpAmount, 0)                              AS ptp_amount,
    toDate(coalesce(ptpDate, 0))                        AS ptp_date,
    coalesce(notes, '')                                 AS notes,
    toDateTime64(coalesce(createdTimeStamp, 0)/1000, 3) AS created_ts,
    toDateTime64(coalesce(updatedTimeStamp, 0)/1000, 3) AS updated_ts,
    coalesce(kodeCabang, '')                            AS kode_cabang,
    __op                                                 AS _op,
    __ts_ms                                             AS _ts_ms,
    __source_ts_ms                                      AS _source_ts_ms,
    if(__deleted = 'true', 1, 0)                        AS _is_deleted
FROM collection_result_queue;

-- ─── 3b. MV: collection_result_queue → collection_result (state) ──────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_collection_result_state TO collection_result AS
SELECT
    uniqueId                                            AS unique_id,
    coalesce(noKontrak, '')                             AS no_kontrak,
    coalesce(callId, '')                                AS call_id,
    coalesce(agentId, '')                               AS agent_id,
    coalesce(classification, '')                        AS classification,
    coalesce(subClassification, '')                     AS sub_classification,
    coalesce(ptpAmount, 0)                              AS ptp_amount,
    toDate(coalesce(ptpDate, 0))                        AS ptp_date,
    coalesce(notes, '')                                 AS notes,
    toDateTime64(coalesce(createdTimeStamp, 0)/1000, 3) AS created_ts,
    toDateTime64(coalesce(updatedTimeStamp, 0)/1000, 3) AS updated_ts,
    coalesce(kodeCabang, '')                            AS kode_cabang,
    __ts_ms                                             AS _version,
    if(__deleted = 'true', 1, 0)                        AS _is_deleted
FROM collection_result_queue;

-- ─── 4. MV: collections_queue → collections_raw ────────────────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_collections_raw TO collections_raw AS
SELECT
    collections_id                                      AS collections_id,
    coalesce(noKontrak, '')                             AS no_kontrak,
    coalesce(agentId, '')                               AS agent_id,
    toDateTime64(coalesce(callDate, 0)/1000, 3)         AS call_date,
    coalesce(classification, '')                        AS classification,
    coalesce(subClassification, '')                     AS sub_classification,
    coalesce(ptpAmount, 0)                              AS ptp_amount,
    toDate(coalesce(ptpDate, 0))                        AS ptp_date,
    coalesce(callStatus, '')                            AS call_status,
    coalesce(notes, '')                                 AS notes,
    toDateTime64(coalesce(createdTimeStamp, 0)/1000, 3) AS created_ts,
    toDateTime64(coalesce(updatedTimeStamp, 0)/1000, 3) AS updated_ts,
    coalesce(kodeCabang, '')                            AS kode_cabang,
    coalesce(overdue, 0)                                AS overdue,
    __op                                                 AS _op,
    __ts_ms                                             AS _ts_ms,
    __source_ts_ms                                      AS _source_ts_ms,
    if(__deleted = 'true', 1, 0)                        AS _is_deleted
FROM collections_queue;

-- ─── 4b. MV: collections_queue → collections (state) ────────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_collections_state TO collections AS
SELECT
    collections_id                                      AS collections_id,
    coalesce(noKontrak, '')                             AS no_kontrak,
    coalesce(agentId, '')                               AS agent_id,
    toDateTime64(coalesce(callDate, 0)/1000, 3)         AS call_date,
    coalesce(classification, '')                        AS classification,
    coalesce(subClassification, '')                     AS sub_classification,
    coalesce(ptpAmount, 0)                              AS ptp_amount,
    toDate(coalesce(ptpDate, 0))                        AS ptp_date,
    coalesce(callStatus, '')                            AS call_status,
    coalesce(notes, '')                                 AS notes,
    toDateTime64(coalesce(createdTimeStamp, 0)/1000, 3) AS created_ts,
    toDateTime64(coalesce(updatedTimeStamp, 0)/1000, 3) AS updated_ts,
    coalesce(kodeCabang, '')                            AS kode_cabang,
    coalesce(overdue, 0)                                AS overdue,
    __ts_ms                                             AS _version,
    if(__deleted = 'true', 1, 0)                        AS _is_deleted
FROM collections_queue;

-- ─── 5. MV: collection_task_queue → collection_task_raw ────────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_collection_task_raw TO collection_task_raw AS
SELECT
    id                                                   AS id,
    coalesce(uniqueId, '')                              AS unique_id,
    coalesce(noKontrak, '')                             AS no_kontrak,
    coalesce(customerName, '')                          AS customer_name,
    coalesce(phoneNumber, '')                           AS phone_number,
    coalesce(overdue, 0)                                AS overdue,
    coalesce(overdueAmount, 0)                          AS overdue_amount,
    coalesce(outStdPkk, 0)                              AS out_std_pkk,
    coalesce(angsuran, 0)                               AS angsuran,
    coalesce(vehicleType, '')                           AS vehicle_type,
    coalesce(vehiclePlate, '')                          AS vehicle_plate,
    coalesce(taskType, '')                              AS task_type,
    coalesce(priority, 0)                               AS priority,
    coalesce(status, '')                                AS status,
    coalesce(assignedAgent, '')                         AS assigned_agent,
    coalesce(kodeCabang, '')                            AS kode_cabang,
    toDateTime64(coalesce(createdTimestamp, 0)/1000, 3) AS created_ts,
    toDateTime64(coalesce(updatedTimestamp, 0)/1000, 3) AS updated_ts,
    __op                                                 AS _op,
    __ts_ms                                             AS _ts_ms,
    __source_ts_ms                                      AS _source_ts_ms,
    if(__deleted = 'true', 1, 0)                        AS _is_deleted
FROM collection_task_queue;

-- ─── 5b. MV: collection_task_queue → collection_task (state) ──────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_collection_task_state TO collection_task AS
SELECT
    id                                                   AS id,
    coalesce(uniqueId, '')                              AS unique_id,
    coalesce(noKontrak, '')                             AS no_kontrak,
    coalesce(customerName, '')                          AS customer_name,
    coalesce(phoneNumber, '')                           AS phone_number,
    coalesce(overdue, 0)                                AS overdue,
    coalesce(overdueAmount, 0)                          AS overdue_amount,
    coalesce(outStdPkk, 0)                              AS out_std_pkk,
    coalesce(angsuran, 0)                               AS angsuran,
    coalesce(vehicleType, '')                           AS vehicle_type,
    coalesce(vehiclePlate, '')                          AS vehicle_plate,
    coalesce(taskType, '')                              AS task_type,
    coalesce(priority, 0)                               AS priority,
    coalesce(status, '')                                AS status,
    coalesce(assignedAgent, '')                         AS assigned_agent,
    coalesce(kodeCabang, '')                            AS kode_cabang,
    toDateTime64(coalesce(createdTimestamp, 0)/1000, 3) AS created_ts,
    toDateTime64(coalesce(updatedTimestamp, 0)/1000, 3) AS updated_ts,
    __ts_ms                                             AS _version,
    if(__deleted = 'true', 1, 0)                        AS _is_deleted
FROM collection_task_queue;

-- ─── 6. MV: customer_id_queue → customer_id_raw ────────────────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_customer_id_raw TO customer_id_raw AS
SELECT
    id                                                   AS id,
    coalesce(noKontrak, '')                             AS no_kontrak,
    coalesce(customerName, '')                          AS customer_name,
    coalesce(phoneNumber, '')                           AS phone_number,
    coalesce(altPhoneNumber, '')                        AS alt_phone,
    coalesce(callStatus, '')                            AS call_status,
    coalesce(priority, 0)                               AS priority,
    coalesce(overdue, 0)                                AS overdue,
    coalesce(outStdPkk, 0)                              AS out_std_pkk,
    coalesce(isPaid, 0)                                 AS is_paid,
    toDate(coalesce(paymentDate, 0))                    AS payment_date,
    coalesce(markedBy, '')                              AS marked_by,
    coalesce(kodeCabang, '')                            AS kode_cabang,
    toDateTime64(coalesce(createdTimestamp, 0)/1000, 3) AS created_ts,
    toDateTime64(coalesce(markedTimestamp, 0)/1000, 3)  AS marked_ts,
    __op                                                 AS _op,
    __ts_ms                                             AS _ts_ms,
    __source_ts_ms                                      AS _source_ts_ms,
    if(__deleted = 'true', 1, 0)                        AS _is_deleted
FROM customer_id_queue;

-- ─── 6b. MV: customer_id_queue → customer_id (state) ──────────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_customer_id_state TO customer_id AS
SELECT
    id                                                   AS id,
    coalesce(noKontrak, '')                             AS no_kontrak,
    coalesce(customerName, '')                          AS customer_name,
    coalesce(phoneNumber, '')                           AS phone_number,
    coalesce(altPhoneNumber, '')                        AS alt_phone,
    coalesce(callStatus, '')                            AS call_status,
    coalesce(priority, 0)                               AS priority,
    coalesce(overdue, 0)                                AS overdue,
    coalesce(outStdPkk, 0)                              AS out_std_pkk,
    coalesce(isPaid, 0)                                 AS is_paid,
    toDate(coalesce(paymentDate, 0))                    AS payment_date,
    coalesce(markedBy, '')                              AS marked_by,
    coalesce(kodeCabang, '')                            AS kode_cabang,
    toDateTime64(coalesce(createdTimestamp, 0)/1000, 3) AS created_ts,
    toDateTime64(coalesce(markedTimestamp, 0)/1000, 3)  AS marked_ts,
    __ts_ms                                             AS _version,
    if(__deleted = 'true', 1, 0)                        AS _is_deleted
FROM customer_id_queue;

-- ─── 7. MV: user_logs_queue → user_logs_raw ────────────────────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_user_logs_raw TO user_logs_raw AS
SELECT
    id                                                   AS id,
    coalesce(username, '')                              AS username,
    coalesce(ipAddress, '')                             AS ip_address,
    coalesce(extension, '')                             AS extension,
    toDateTime64(coalesce(inTimeStamp, 0)/1000, 3)      AS in_ts,
    if(outTimeStamp IS NULL OR outTimeStamp = 0, toDateTime64(0, 3), toDateTime64(outTimeStamp/1000, 3)) AS out_ts,
    coalesce(duration, 0)                               AS duration,
    coalesce(kodeCabang, '')                            AS kode_cabang,
    __op                                                 AS _op,
    __ts_ms                                             AS _ts_ms,
    __source_ts_ms                                      AS _source_ts_ms,
    if(__deleted = 'true', 1, 0)                        AS _is_deleted
FROM user_logs_queue;

-- ─── 7b. MV: user_logs_queue → user_logs (state) ───────────────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_user_logs_state TO user_logs AS
SELECT
    id                                                   AS id,
    coalesce(username, '')                              AS username,
    coalesce(ipAddress, '')                             AS ip_address,
    coalesce(extension, '')                             AS extension,
    toDateTime64(coalesce(inTimeStamp, 0)/1000, 3)      AS in_ts,
    if(outTimeStamp IS NULL OR outTimeStamp = 0, toDateTime64(0, 3), toDateTime64(outTimeStamp/1000, 3)) AS out_ts,
    coalesce(duration, 0)                               AS duration,
    coalesce(kodeCabang, '')                            AS kode_cabang,
    __ts_ms                                             AS _version,
    if(__deleted = 'true', 1, 0)                        AS _is_deleted
FROM user_logs_queue;

-- ─── 8. MV: user_releases_queue → user_releases_raw ───────────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_user_releases_raw TO user_releases_raw AS
SELECT
    id                                                   AS id,
    hash                                                 AS hash,
    coalesce(username, '')                              AS username,
    toDate(coalesce(releaseDate, 0))                    AS release_date,
    coalesce(totalTask, 0)                              AS total_task,
    coalesce(totalCalled, 0)                            AS total_called,
    coalesce(totalAnswered, 0)                          AS total_answered,
    coalesce(totalPTP, 0)                               AS total_ptp,
    coalesce(talkTimeSec, 0)                            AS talk_time_sec,
    coalesce(status, '')                                AS status,
    coalesce(kodeCabang, '')                            AS kode_cabang,
    toDateTime64(coalesce(createdTimestamp, 0)/1000, 3) AS created_ts,
    toDateTime64(coalesce(updatedTimestamp, 0)/1000, 3) AS updated_ts,
    __op                                                 AS _op,
    __ts_ms                                             AS _ts_ms,
    __source_ts_ms                                      AS _source_ts_ms,
    if(__deleted = 'true', 1, 0)                        AS _is_deleted
FROM user_releases_queue;

-- ─── 8b. MV: user_releases_queue → user_releases (state) ──────────────────────
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_user_releases_state TO user_releases AS
SELECT
    id                                                   AS id,
    hash                                                 AS hash,
    coalesce(username, '')                              AS username,
    toDate(coalesce(releaseDate, 0))                    AS release_date,
    coalesce(totalTask, 0)                              AS total_task,
    coalesce(totalCalled, 0)                            AS total_called,
    coalesce(totalAnswered, 0)                          AS total_answered,
    coalesce(totalPTP, 0)                               AS total_ptp,
    coalesce(talkTimeSec, 0)                            AS talk_time_sec,
    coalesce(status, '')                                AS status,
    coalesce(kodeCabang, '')                            AS kode_cabang,
    toDateTime64(coalesce(createdTimestamp, 0)/1000, 3) AS created_ts,
    toDateTime64(coalesce(updatedTimestamp, 0)/1000, 3) AS updated_ts,
    __ts_ms                                             AS _version,
    if(__deleted = 'true', 1, 0)                        AS _is_deleted
FROM user_releases_queue;
