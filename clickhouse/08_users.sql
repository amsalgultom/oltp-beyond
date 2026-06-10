-- ─────────────────────────────────────────────────────────────────────────────
--  08_users.sql
--  User management — least privilege untuk Next.js dashboard.
--
--  IMPORTANT: env var CLICKHOUSE_ADMIN_PASSWORD & CLICKHOUSE_READONLY_PASSWORD
--  sudah diset via docker-compose saat inisialisasi.
--  Script ini membuat user read-only tambahan & grant permission.
-- ─────────────────────────────────────────────────────────────────────────────

-- Catatan: User 'default' sudah ada dengan password CLICKHOUSE_ADMIN_PASSWORD

-- ─── User read-only untuk dashboard Next.js ────────────────────────────────────
-- Username: ch_readonly
-- Password: dari env CLICKHOUSE_READONLY_PASSWORD (docker-compose)
-- Hak: SELECT saja pada collection database

CREATE USER IF NOT EXISTS ch_readonly
  IDENTIFIED WITH plaintext_password BY 'dummy_placeholder'
  SETTINGS
    max_rows_to_read = 1000000,
    max_execution_time = 60;

-- Grant SELECT pada semua tabel di collection
GRANT SELECT ON collection.* TO ch_readonly;

-- Jangan grant DELETE, CREATE, ALTER, DROP, dll — minimal privilege

-- ─── ALTER user jika perlu ganti password (uncomment & eksekusi manual) ───────
-- ALTER USER ch_readonly IDENTIFIED WITH plaintext_password BY '<new_password>';

-- ─── Quota (opsional — jika butuh resource control) ───────────────────────────
-- CREATE QUOTA IF NOT EXISTS dashboard_quota
--   FOR ch_readonly
--   KEYED BY user_name
--   WITH MAX queries=1000, max_execution_time=60
--   FOR MONTH;

SELECT 'Users created successfully.' AS status;
SHOW USERS;
SHOW GRANTS FOR ch_readonly;
