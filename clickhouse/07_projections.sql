-- ─────────────────────────────────────────────────────────────────────────────
--  07_projections.sql
--  Projections — pre-agg alternatif, terinspirasi oleh Materialized Index.
--  Digunakan jika MV terlalu berat. Untuk kasus ini, MV sudah cukup.
--  File ini adalah placeholder untuk extensibility.
-- ─────────────────────────────────────────────────────────────────────────────

USE collection;

-- Projection example (opsional) — untuk query cdr by disposition
-- ALTER TABLE cdr ADD PROJECTION proj_disposition_summary
-- SELECT disposition, count() cnt, sum(billsec) talk_sec
-- GROUP BY disposition
-- SETTINGS index_granularity = 256;

-- Untuk saat ini, gunakan agg_* + MV saja.
-- Projections bisa ditambahkan di upgrade phase jika perlu optimasi lebih.
