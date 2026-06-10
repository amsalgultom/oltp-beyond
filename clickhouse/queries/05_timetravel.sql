-- ─────────────────────────────────────────────────────────────────────────────
--  05_timetravel.sql
--  Time Travel — as-of query menggunakan tabel *_raw append-only.
--  Digunakan oleh: GET /api/timetravel?asof=2026-05-01
--
--  Parameter: asof (date string 'YYYY-MM-DD')
--  Return: customer antrian state "pada tanggal X"
-- ─────────────────────────────────────────────────────────────────────────────

-- Contoh: State antrian per 15 Mei 2026 pukul 23:59:59
WITH asof_ts AS (
    SELECT toUnixTimestamp64Milli(toDateTime('2026-05-15 23:59:59', 'UTC')) AS ts_ms
),
state_asof AS (
    SELECT
        id,
        no_kontrak,
        customer_name,
        phone_number,
        call_status,
        priority,
        overdue,
        out_std_pkk,
        is_paid,
        payment_date,
        marked_by,
        kode_cabang,
        argMax(call_status, _ts_ms) AS final_call_status,
        argMax(overdue, _ts_ms) AS final_overdue,
        argMax(is_paid, _ts_ms) AS final_is_paid,
        argMax(marked_by, _ts_ms) AS final_marked_by,
        argMax(_is_deleted, _ts_ms) AS final_is_deleted
    FROM customer_id_raw, asof_ts
    WHERE _ts_ms <= asof_ts.ts_ms
    GROUP BY id, no_kontrak, customer_name, phone_number, call_status, priority, overdue, out_std_pkk, is_paid, payment_date, marked_by, kode_cabang
)
SELECT
    no_kontrak,
    customer_name,
    phone_number,
    final_call_status AS call_status,
    priority,
    final_overdue AS overdue,
    out_std_pkk,
    final_is_paid AS is_paid,
    final_marked_by AS current_agent
FROM state_asof
WHERE final_is_deleted = 0
ORDER BY priority, final_overdue DESC;

-- Audit trail per kontrak (semua perubahan urut waktu)
-- SELECT
--     _ts_ms,
--     _op,
--     call_status,
--     overdue,
--     is_paid,
--     marked_by
-- FROM customer_id_raw
-- WHERE no_kontrak = 'KTR-001001'
-- ORDER BY _ts_ms;
