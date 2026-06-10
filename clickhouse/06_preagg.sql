-- ─────────────────────────────────────────────────────────────────────────────
--  06_preagg.sql
--  Pre-aggregation tables — AggregatingMergeTree + MV untuk fast analytics.
-- ─────────────────────────────────────────────────────────────────────────────

USE collection;

-- ─── Agent Daily Summary (pre-agg) ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agg_agent_daily
(
    work_date           Date,
    agent_username      LowCardinality(String),
    branch_code         LowCardinality(String),
    tasks_assigned      AggregateFunction(sum, Int32),
    calls_made          AggregateFunction(sum, Int32),
    calls_answered      AggregateFunction(sum, Int32),
    ptp_achieved        AggregateFunction(sum, Int32),
    talk_time_seconds   AggregateFunction(sum, Int32),
    ptp_amount          AggregateFunction(sum, Float64)
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(work_date)
ORDER BY (work_date, agent_username, branch_code)
SETTINGS index_granularity = 8192;

-- MV: user_releases → agg_agent_daily (hanya record CLOSED untuk prod)
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_agg_agent_daily TO agg_agent_daily AS
SELECT
    release_date                                AS work_date,
    username                                    AS agent_username,
    kode_cabang                                 AS branch_code,
    sumState(total_task)                        AS tasks_assigned,
    sumState(total_called)                      AS calls_made,
    sumState(total_answered)                    AS calls_answered,
    sumState(total_ptp)                         AS ptp_achieved,
    sumState(talk_time_sec)                     AS talk_time_seconds,
    sumState(cast(0 as Float64))                AS ptp_amount  -- ClickHouse SDK bisa join dgn collection_result
FROM user_releases
WHERE _is_deleted = 0 AND status = 'CLOSED'
GROUP BY work_date, agent_username, branch_code;

-- ─── CDR Minutely Summary (real-time streaming) ────────────────────────────────
CREATE TABLE IF NOT EXISTS agg_cdr_minutely
(
    minute              DateTime64(3),
    total_calls         AggregateFunction(count),
    answered_calls      AggregateFunction(countIf, UInt8),
    total_duration      AggregateFunction(sum, Int32),
    total_billsec       AggregateFunction(sum, Int32),
    branch_code         LowCardinality(String)
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(toDate(minute))
ORDER BY (minute, branch_code)
SETTINGS index_granularity = 8192;

-- MV: cdr → agg_cdr_minutely
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_agg_cdr_minutely TO agg_cdr_minutely AS
SELECT
    toStartOfMinute(calldate)                   AS minute,
    countState()                                AS total_calls,
    countIfState(if(disposition = 'ANSWERED', 1, 0)) AS answered_calls,
    sumState(duration)                          AS total_duration,
    sumState(billsec)                           AS total_billsec,
    kode_cabang                                 AS branch_code
FROM cdr
WHERE _is_deleted = 0
GROUP BY minute, branch_code;

-- ─── Collection Result Summary (harian) ────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agg_collection_daily
(
    event_date          Date,
    classification      LowCardinality(String),
    count               AggregateFunction(count),
    ptp_total_amount    AggregateFunction(sum, Float64),
    branch_code         LowCardinality(String)
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, classification, branch_code)
SETTINGS index_granularity = 8192;

-- MV: collection_result → agg_collection_daily
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_agg_collection_daily TO agg_collection_daily AS
SELECT
    toDate(created_ts)                          AS event_date,
    classification                              AS classification,
    countState()                                AS count,
    sumState(ptp_amount)                        AS ptp_total_amount,
    kode_cabang                                 AS branch_code
FROM collection_result
WHERE _is_deleted = 0
GROUP BY event_date, classification, branch_code;

-- ─── CDR Disposition Distribution ─────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS agg_disposition_summary
(
    count_date          Date,
    disposition         LowCardinality(String),
    count               AggregateFunction(count),
    avg_talk_sec        AggregateFunction(avg, Float32),
    branch_code         LowCardinality(String)
)
ENGINE = AggregatingMergeTree
PARTITION BY toYYYYMM(count_date)
ORDER BY (count_date, disposition, branch_code)
SETTINGS index_granularity = 8192;

-- MV: cdr → agg_disposition_summary
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_agg_disposition_summary TO agg_disposition_summary AS
SELECT
    toDate(calldate)                            AS count_date,
    disposition                                 AS disposition,
    countState()                                AS count,
    avgState(toFloat32(billsec))                 AS avg_talk_sec,
    kode_cabang                                 AS branch_code
FROM cdr
WHERE _is_deleted = 0
GROUP BY count_date, disposition, branch_code;

-- Query helpers untuk aplikasi (Next.js)

-- Real-time: Calls per minute last 60 min
CREATE OR REPLACE VIEW vq_live_cdr_minute AS
SELECT
    minute,
    countMerge(total_calls)         AS calls,
    countMerge(answered_calls)  AS answered,
    round(100.0 * answered / nullIf(calls, 0), 1) AS connect_rate_pct,
    sumMerge(total_billsec)          AS total_talk_sec,
    branch_code
FROM agg_cdr_minutely
WHERE minute >= now() - INTERVAL 60 MINUTE
GROUP BY minute, branch_code
ORDER BY minute DESC;

-- Agent productivity (harian)
CREATE OR REPLACE VIEW vq_agent_productivity AS
SELECT
    work_date,
    agent_username,
    sumMerge(tasks_assigned)      AS tasks,
    sumMerge(calls_made)          AS calls,
    sumMerge(calls_answered)      AS answered,
    sumMerge(ptp_achieved)        AS ptp,
    sumMerge(talk_time_seconds)   AS talk_sec,
    branch_code,
    round(100.0 * answered / nullIf(calls, 0), 1) AS connect_rate_pct,
    round(100.0 * ptp / nullIf(answered, 0), 1)   AS ptp_rate_pct
FROM agg_agent_daily
GROUP BY work_date, agent_username, branch_code
ORDER BY work_date DESC, talk_sec DESC;

-- Disposition summary
CREATE OR REPLACE VIEW vq_disposition_dist AS
SELECT
    count_date,
    disposition,
    countMerge(count)      AS total,
    avgMerge(avg_talk_sec) AS avg_talk_seconds,
    branch_code
FROM agg_disposition_summary
GROUP BY count_date, disposition, branch_code
ORDER BY count_date DESC, total DESC;
