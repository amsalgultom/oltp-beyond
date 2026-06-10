-- ─────────────────────────────────────────────────────────────────────────────
--  02_funnel.sql
--  Collection funnel — 5 tahap: Task → Called → Answered → PTP → Paid
--  Digunakan oleh: GET /api/funnel
--  Menunjukkan conversion rate tiap tahap.
-- ─────────────────────────────────────────────────────────────────────────────

-- Events terpadu per kontrak (7 hari terakhir)
WITH events AS (
    -- Step 1: Task dibuat
    SELECT
        no_kontrak,
        created_ts AS ts,
        1 AS step
    FROM collection_task FINAL
    WHERE _is_deleted = 0 AND created_ts >= now() - INTERVAL 7 DAY

    UNION ALL
    -- Step 2: Di-call
    SELECT
        contract_no,
        calldate,
        2
    FROM cdr FINAL
    WHERE _is_deleted = 0 AND calldate >= now() - INTERVAL 7 DAY AND contract_no != ''

    UNION ALL
    -- Step 3: Tersambung (RPC / ANSWERED)
    SELECT
        contract_no,
        calldate,
        3
    FROM cdr FINAL
    WHERE _is_deleted = 0 AND disposition = 'ANSWERED' AND calldate >= now() - INTERVAL 7 DAY AND contract_no != ''

    UNION ALL
    -- Step 4: PTP (Promise To Pay)
    SELECT
        no_kontrak,
        created_ts,
        4
    FROM collection_result FINAL
    WHERE _is_deleted = 0 AND classification = 'PTP' AND created_ts >= now() - INTERVAL 7 DAY

    UNION ALL
    -- Step 5: Bayar / Lunas
    SELECT
        no_kontrak,
        toDateTime64(payment_date, 3),
        5
    FROM customer_id FINAL
    WHERE _is_deleted = 0 AND is_paid = 1 AND payment_date >= toDate(now() - INTERVAL 7 DAY)
)

-- windowFunnel: jendela 7 hari, urutan ketat
SELECT
    level,
    count() AS contracts,
    round(100.0 * contracts / (SELECT count() FROM (SELECT DISTINCT no_kontrak FROM events WHERE step = 1)), 1) AS pct_of_total
FROM (
    SELECT
        no_kontrak,
        windowFunnel(604800)(   -- 7 hari = 604800 detik
            ts,
            step = 1,
            step = 2,
            step = 3,
            step = 4,
            step = 5
        ) AS level
    FROM events
    GROUP BY no_kontrak
)
GROUP BY level
ORDER BY level
SETTINGS max_rows_to_read = 1000000;
