-- ─────────────────────────────────────────────────────────────────────────────
--  03_distribution.sql
--  Distribution analytics — histogram, quantiles, aging buckets, dispositions.
--  Digunakan oleh: GET /api/distribution
-- ─────────────────────────────────────────────────────────────────────────────

-- [1] Talk duration — quantiles & histogram
SELECT
    'talk_duration' AS metric,
    quantilesCont(0.5, 0.75, 0.9, 0.95, 0.99)(billsec) AS quantiles,
    round(avg(billsec), 1) AS mean_sec,
    max(billsec) AS max_sec,
    min(billsec) AS min_sec
FROM cdr FINAL
WHERE _is_deleted = 0 AND disposition = 'ANSWERED'
    AND toDate(calldate) >= toDate(now() - INTERVAL 30 DAY);

-- [2] CDR by disposition (pie)
SELECT
    disposition,
    count() AS total,
    round(100.0 * total / sum(total) OVER (), 1) AS pct
FROM cdr FINAL
WHERE _is_deleted = 0 AND toDate(calldate) >= toDate(now() - INTERVAL 30 DAY)
GROUP BY disposition
ORDER BY total DESC;

-- [3] Task by aging bucket (overdue distribution)
SELECT
    aging_bucket,
    count() AS kontrak_count,
    round(avg(days_overdue), 1) AS avg_days,
    round(sum(outstanding_amount) / 1000000, 2) AS total_outstanding_mio,
    branch_code
FROM v_collection_task
GROUP BY aging_bucket, branch_code
ORDER BY
    CASE
        WHEN aging_bucket = '1-30' THEN 1
        WHEN aging_bucket = '31-60' THEN 2
        WHEN aging_bucket = '61-90' THEN 3
        ELSE 4
    END;

-- [4] PTP success rate by agent (last 7 days)
SELECT
    cr.agent_id,
    count() AS ptp_count,
    countIf(cr.classification = 'PTP') AS ptp_yes,
    countIf(cr.classification = 'RPC') AS rpc_count,
    round(100.0 * ptp_yes / nullIf(count(), 0), 1) AS ptp_success_pct
FROM collection_result FINAL cr
WHERE cr._is_deleted = 0
    AND cr.created_ts >= now() - INTERVAL 7 DAY
GROUP BY cr.agent_id
ORDER BY ptp_success_pct DESC;

-- [5] Collection result by classification (daily)
SELECT
    toDate(created_ts) AS date,
    classification,
    count() AS result_count,
    round(sum(ptp_amount) / 1000000, 2) AS ptp_amount_mio
FROM collection_result FINAL
WHERE _is_deleted = 0
    AND toDate(created_ts) >= toDate(now() - INTERVAL 30 DAY)
GROUP BY date, classification
ORDER BY date DESC, result_count DESC;
