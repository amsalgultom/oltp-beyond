-- ─────────────────────────────────────────────────────────────────────────────
--  01_streaming.sql
--  Real-time dashboard — live metrics per minute.
--  Digunakan oleh: GET /api/streaming
--  Interval: refresh tiap 5-10 detik dari client (Next.js).
-- ─────────────────────────────────────────────────────────────────────────────

-- [1] Calls per minute (last 60 minutes)
SELECT
    minute,
    calls,
    answered,
    connect_rate_pct,
    round(total_talk_sec / 60, 1) AS total_talk_min,
    branch_code
FROM vq_live_cdr_minute
ORDER BY minute DESC
LIMIT 60;

-- [2] Agent status now (online/break/offline)
-- SELECT
--     agent_id,
--     status,
--     login_date,
--     branch_code
-- FROM v_agent_login_status
-- WHERE status IN ('1', '2')  -- 1=online, 2=break
-- ORDER BY agent_id;

-- [3] Queue status now
-- SELECT
--     COUNT()                         AS total_in_queue,
--     countIf(status = 'CALLING')     AS currently_calling,
--     countIf(status = 'DONE')        AS completed,
--     branch_code
-- FROM v_customer_queue
-- WHERE status IN ('IN_QUEUE', 'CALLING', 'DONE')
-- GROUP BY branch_code;
