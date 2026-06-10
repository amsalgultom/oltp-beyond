-- ─────────────────────────────────────────────────────────────────────────────
--  05_dim_fact_views.sql
--  VIEW normalisasi di atas tabel state — untuk query analitik.
--  Semua query aplikasi menggunakan VIEW ini, bukan tabel raw/state.
-- ─────────────────────────────────────────────────────────────────────────────

USE collection;

-- ─── v_agent_login_status ─────────────────────────────────────────────────────
CREATE OR REPLACE VIEW v_agent_login_status AS
SELECT
    marked_by           AS agent_id,
    state               AS status,
    login_date,
    login_time,
    extension,
    ip_address,
    now() - toDateTime64(cast(login_date as UInt32) * 86400 + login_time / 1000.0, 3) AS session_duration
FROM agent_login_status FINAL
WHERE _is_deleted = 0;

-- ─── v_cdr (CDR bersih dengan join ke collection_result) ─────────────────────
CREATE OR REPLACE VIEW v_cdr AS
SELECT
    cdr.uniqueid,
    cdr.calldate,
    cdr.src                                    AS source_number,
    cdr.dst                                    AS destination_number,
    cdr.duration,
    cdr.billsec                                AS talk_seconds,
    cdr.disposition,
    cdr.accountcode,
    cdr.contract_no,
    cdr.customer_no,
    cdr.phone_number,
    cdr.username                               AS agent_username,
    cdr.kode_cabang                            AS branch_code,
    coalesce(cr.classification, 'NO_RESULT')   AS result_classification,
    coalesce(cr.ptp_amount, 0)                 AS ptp_amount,
    coalesce(cr.ptp_date, NULL)                AS ptp_date
FROM cdr FINAL cdr
LEFT JOIN collection_result FINAL cr ON cr.call_id = cdr.uniqueid
WHERE cdr._is_deleted = 0 AND (cr._is_deleted = 0 OR cr._is_deleted IS NULL);

-- ─── v_collection_task (task dengan aging bucket) ────────────────────────────
CREATE OR REPLACE VIEW v_collection_task AS
SELECT
    id,
    unique_id,
    no_kontrak                                  AS contract_no,
    customer_name,
    phone_number,
    overdue                                     AS days_overdue,
    overdue_amount,
    out_std_pkk                                 AS outstanding_amount,
    angsuran                                    AS installment_amount,
    vehicle_type,
    vehicle_plate,
    task_type,
    priority,
    status,
    assigned_agent                              AS agent_username,
    kode_cabang                                 AS branch_code,
    created_ts,
    updated_ts,
    CASE
        WHEN overdue <= 30 THEN '1-30'
        WHEN overdue <= 60 THEN '31-60'
        WHEN overdue <= 90 THEN '61-90'
        ELSE '90+'
    END                                         AS aging_bucket
FROM collection_task FINAL
WHERE _is_deleted = 0;

-- ─── v_customer_queue (status antrian penagihan) ────────────────────────────
CREATE OR REPLACE VIEW v_customer_queue AS
SELECT
    id,
    no_kontrak                                  AS contract_no,
    customer_name,
    phone_number,
    alt_phone,
    call_status                                 AS status,
    priority,
    overdue                                     AS days_overdue,
    out_std_pkk                                 AS outstanding_amount,
    is_paid                                     AS already_paid,
    payment_date,
    marked_by                                   AS current_agent,
    kode_cabang                                 AS branch_code,
    created_ts,
    marked_ts                                   AS last_update_ts
FROM customer_id FINAL
WHERE _is_deleted = 0;

-- ─── v_user_session (sesi kerja agent) ────────────────────────────────────────
CREATE OR REPLACE VIEW v_user_session AS
SELECT
    id,
    username                                    AS agent_username,
    ip_address,
    extension,
    in_ts                                       AS login_time,
    out_ts                                      AS logout_time,
    duration                                    AS session_duration_seconds,
    if(out_ts IS NULL, 'ACTIVE', 'CLOSED')     AS session_status,
    kode_cabang                                 AS branch_code
FROM user_logs FINAL
WHERE _is_deleted = 0;

-- ─── v_agent_daily_summary (ringkasan harian per agent) ──────────────────────
CREATE OR REPLACE VIEW v_agent_daily_summary AS
SELECT
    toDate(created_ts)                          AS work_date,
    username                                    AS agent_username,
    total_task                                  AS tasks_assigned,
    total_called                                AS calls_made,
    total_answered                              AS calls_answered,
    total_ptp                                   AS ptp_achieved,
    talk_time_sec                               AS total_talk_seconds,
    kode_cabang                                 AS branch_code,
    CASE
        WHEN total_called > 0 THEN round(100.0 * total_answered / total_called, 1)
        ELSE 0
    END                                         AS connect_rate_pct,
    CASE
        WHEN total_answered > 0 THEN round(100.0 * total_ptp / total_answered, 1)
        ELSE 0
    END                                         AS ptp_closure_rate_pct
FROM user_releases FINAL
WHERE _is_deleted = 0 AND status = 'CLOSED';

-- ─── v_collection_result_summary ──────────────────────────────────────────────
CREATE OR REPLACE VIEW v_collection_result_summary AS
SELECT
    toDate(created_ts)                          AS event_date,
    classification                              AS result_type,
    count()                                     AS count,
    sumIf(ptp_amount, classification = 'PTP')   AS ptp_total_amount,
    kode_cabang                                 AS branch_code
FROM collection_result FINAL
WHERE _is_deleted = 0
GROUP BY event_date, classification, kode_cabang;
