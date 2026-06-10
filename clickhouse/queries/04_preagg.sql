-- ─────────────────────────────────────────────────────────────────────────────
--  04_preagg.sql
--  Pre-aggregated queries — cepat karena sudah teragregasi saat ingest.
--  Digunakan oleh: GET /api/preagg
-- ─────────────────────────────────────────────────────────────────────────────

-- [1] Agent productivity per hari (last 30 days)
SELECT
    work_date,
    agent_username,
    tasks,
    calls,
    answered,
    ptp,
    round(talk_sec / 60, 1) AS talk_minutes,
    connect_rate_pct,
    ptp_rate_pct,
    branch_code
FROM vq_agent_productivity
WHERE work_date >= toDate(now() - INTERVAL 30 DAY)
ORDER BY work_date DESC, talk_sec DESC;

-- [2] Total productivity harian (aggregate semua agent)
SELECT
    work_date,
    sumMerge(tasks_assigned) AS total_tasks,
    sumMerge(calls_made) AS total_calls,
    sumMerge(calls_answered) AS total_answered,
    sumMerge(ptp_achieved) AS total_ptp,
    round(sumMerge(talk_time_seconds) / 60, 0) AS total_talk_minutes
FROM agg_agent_daily
WHERE work_date >= toDate(now() - INTERVAL 30 DAY)
GROUP BY work_date
ORDER BY work_date DESC;

-- [3] Disposition distribution per hari
SELECT
    count_date,
    disposition,
    countMerge(count) AS total_calls,
    round(avgMerge(avg_talk_sec), 1) AS avg_talk_seconds
FROM agg_disposition_summary
WHERE count_date >= toDate(now() - INTERVAL 30 DAY)
GROUP BY count_date, disposition
ORDER BY count_date DESC, total_calls DESC;

-- [4] Collection result summary per hari
SELECT
    event_date,
    classification,
    countMerge(count) AS result_count,
    round(sumMerge(ptp_total_amount) / 1000000, 2) AS ptp_amount_mio
FROM agg_collection_daily
WHERE event_date >= toDate(now() - INTERVAL 30 DAY)
GROUP BY event_date, classification
ORDER BY event_date DESC, result_count DESC;

-- [5] Top agents by talk time (minggu terakhir)
SELECT
    agent_username,
    sumMerge(talk_time_seconds) AS total_talk_sec,
    sumMerge(calls_made) AS total_calls,
    sumMerge(ptp_achieved) AS ptp_count,
    round(total_talk_sec / nullIf(total_calls, 0), 1) AS avg_talk_per_call,
    branch_code
FROM agg_agent_daily
WHERE work_date >= toDate(now() - INTERVAL 7 DAY)
GROUP BY agent_username, branch_code
ORDER BY total_talk_sec DESC
LIMIT 20;
