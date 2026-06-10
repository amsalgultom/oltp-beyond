-- ─────────────────────────────────────────────────────────────────────────────
--  check-source-prereq.sql
--  Validasi prasyarat CDC di server MariaDB sumber sebelum menyalakan Debezium.
--
--  Cara pakai:
--    mysql -h<MARIADB_HOST> -P<PORT> -u<debezium_user> -p < source/check-source-prereq.sql
--    atau: make prereq
--
--  Output yang diharapkan (semua harus PASS):
--    [1] Version          : 5.5.60-MariaDB (atau lebih baru)
--    [2] log_bin          : ON     ← WAJIB
--    [3] binlog_format    : ROW    ← WAJIB
--    [4] binlog_row_image : FULL   ← idealnya FULL (5.5 selalu FULL)
--    [5] MASTER STATUS    : ada file & position
--    [6] User grants      : SELECT, RELOAD, REPLICATION SLAVE/CLIENT
--    [7] Database exist   : prod_5_smg_mirror_ad
--    [8] 8 tabel ada      : semua tabel (tblCustomerId_copy TIDAK dicek)
--    [9] InnoDB tables    : semua tabel = InnoDB (snapshot lock minimal)
-- ─────────────────────────────────────────────────────────────────────────────

-- Nonaktifkan paging agar output mudah dibaca di script
SET SESSION long_query_time = 60;

SELECT '════════════════════════════════════════════════════════════════' AS '';
SELECT '  CDC Prerequisite Check — prod_5_smg_mirror_ad (MariaDB)     ' AS '';
SELECT '════════════════════════════════════════════════════════════════' AS '';

-- ─── [1] Versi MariaDB ────────────────────────────────────────────────────────
SELECT
  '[1] MariaDB Version' AS check_name,
  @@VERSION AS value,
  CASE
    WHEN @@VERSION LIKE '%MariaDB%' THEN 'INFO — MariaDB terdeteksi'
    WHEN @@VERSION LIKE '5.%'       THEN 'WARN — Versi tua (5.x); uji connector dengan hati-hati'
    ELSE 'INFO'
  END AS result;

-- ─── [2] Binlog aktif ─────────────────────────────────────────────────────────
SELECT
  '[2] log_bin (binlog aktif)' AS check_name,
  @@log_bin AS value,
  CASE @@log_bin
    WHEN 1 THEN 'PASS — Binlog aktif'
    ELSE        'FAIL — Binlog TIDAK aktif! Set log_bin=ON di my.cnf lalu restart.'
  END AS result;

-- ─── [3] Format binlog = ROW ──────────────────────────────────────────────────
SELECT
  '[3] binlog_format' AS check_name,
  @@binlog_format AS value,
  CASE UPPER(@@binlog_format)
    WHEN 'ROW'       THEN 'PASS — Format ROW (wajib untuk CDC)'
    WHEN 'MIXED'     THEN 'FAIL — MIXED tidak didukung Debezium; ubah ke ROW'
    WHEN 'STATEMENT' THEN 'FAIL — STATEMENT tidak didukung; ubah ke ROW'
    ELSE                  'FAIL — Format tidak dikenal'
  END AS result;

-- ─── [4] Row image = FULL ─────────────────────────────────────────────────────
SELECT
  '[4] binlog_row_image' AS check_name,
  IFNULL(@@binlog_row_image, 'N/A (MariaDB 5.5 = selalu FULL)') AS value,
  CASE
    WHEN @@binlog_row_image IS NULL        THEN 'INFO — MariaDB 5.5 tidak punya variabel ini; selalu FULL'
    WHEN UPPER(@@binlog_row_image) = 'FULL' THEN 'PASS — FULL (before-image lengkap)'
    ELSE CONCAT('WARN — ', @@binlog_row_image, '; direkomendasikan FULL')
  END AS result;

-- ─── [5] Binlog retention ────────────────────────────────────────────────────
SELECT
  '[5] expire_logs_days' AS check_name,
  IFNULL(@@expire_logs_days, 0) AS value,
  CASE
    WHEN IFNULL(@@expire_logs_days, 0) = 0  THEN 'WARN — 0 = tidak pernah dihapus; risiko disk penuh'
    WHEN @@expire_logs_days < 3              THEN 'WARN — < 3 hari; mungkin kurang saat snapshot besar'
    WHEN @@expire_logs_days >= 7             THEN 'PASS — Retensi >= 7 hari (cukup)'
    ELSE                                          'INFO — Retensi cukup untuk CDC'
  END AS result;

-- ─── [6] Server ID unik ──────────────────────────────────────────────────────
SELECT
  '[6] server_id' AS check_name,
  @@server_id AS value,
  CASE
    WHEN @@server_id = 0 THEN 'FAIL — server_id=0 tidak valid; set nilai unik di my.cnf'
    ELSE CONCAT('INFO — server_id=', @@server_id, '; pastikan Debezium pakai server_id BERBEDA (mis. 184)')
  END AS result;

-- ─── [7] MASTER STATUS (posisi binlog saat ini) ───────────────────────────────
SELECT '--- [7] MASTER STATUS (posisi binlog) ---' AS '';
SHOW MASTER STATUS;
-- Jika kosong: binlog belum aktif atau akun tidak punya REPLICATION CLIENT

-- ─── [8] Hak akses user CDC ──────────────────────────────────────────────────
SELECT '--- [8] Grants user saat ini ---' AS '';
SHOW GRANTS FOR CURRENT_USER();
-- Cek: SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT
-- Jika muncul error "Access denied", user tidak punya izin melihat grants sendiri

-- ─── [9] Database target ada ─────────────────────────────────────────────────
SELECT
  '[9] Database prod_5_smg_mirror_ad' AS check_name,
  COUNT(*) AS db_count,
  CASE COUNT(*)
    WHEN 1 THEN 'PASS — Database ditemukan'
    ELSE        'FAIL — Database tidak ditemukan; cek MARIADB_DATABASE di .env'
  END AS result
FROM information_schema.SCHEMATA
WHERE SCHEMA_NAME = 'prod_5_smg_mirror_ad';

-- ─── [10] 8 tabel ada (tblCustomerId_copy TIDAK dicek) ───────────────────────
SELECT
  '[10] Tabel ada' AS check_name,
  TABLE_NAME,
  ENGINE,
  TABLE_ROWS AS approx_rows,
  CASE
    WHEN ENGINE = 'InnoDB' THEN 'PASS — InnoDB (snapshot lock minimal)'
    ELSE                        CONCAT('WARN — ', ENGINE, ' bukan InnoDB; snapshot bisa ambil lock lebih lama')
  END AS engine_check
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'prod_5_smg_mirror_ad'
  AND TABLE_NAME IN (
    'tblAgentLoginStatus',
    'tblCallDataRecords',
    'tblCollectionResult',
    'tblCollections',
    'tblCollectionTask',
    'tblCustomerId',
    'tblUserLogs',
    'tblUserReleases'
  )
ORDER BY TABLE_NAME;

-- Hitung berapa tabel yang ditemukan (harus 8)
SELECT
  '[10b] Jumlah tabel' AS check_name,
  COUNT(*) AS found,
  CASE COUNT(*)
    WHEN 8 THEN 'PASS — Semua 8 tabel ada'
    ELSE        CONCAT('FAIL — Hanya ', COUNT(*), '/8 tabel ditemukan; cek nama tabel di server')
  END AS result
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'prod_5_smg_mirror_ad'
  AND TABLE_NAME IN (
    'tblAgentLoginStatus', 'tblCallDataRecords', 'tblCollectionResult',
    'tblCollections', 'tblCollectionTask', 'tblCustomerId',
    'tblUserLogs', 'tblUserReleases'
  );

-- ─── [11] Ukuran tabel (estimasi; berguna untuk estimasi waktu snapshot) ───────
SELECT
  '[11] Estimasi ukuran tabel' AS check_name,
  TABLE_NAME,
  ROUND((DATA_LENGTH + INDEX_LENGTH) / 1024 / 1024, 1) AS size_mb,
  TABLE_ROWS AS approx_rows
FROM information_schema.TABLES
WHERE TABLE_SCHEMA = 'prod_5_smg_mirror_ad'
  AND TABLE_NAME IN (
    'tblAgentLoginStatus', 'tblCallDataRecords', 'tblCollectionResult',
    'tblCollections', 'tblCollectionTask', 'tblCustomerId',
    'tblUserLogs', 'tblUserReleases'
  )
ORDER BY (DATA_LENGTH + INDEX_LENGTH) DESC;

-- ─── [12] Kolom timestamp (verifikasi CDC ordering) ──────────────────────────
SELECT
  '[12] Kolom timestamp CDC' AS check_name,
  TABLE_NAME,
  COLUMN_NAME,
  DATA_TYPE,
  IS_NULLABLE
FROM information_schema.COLUMNS
WHERE TABLE_SCHEMA = 'prod_5_smg_mirror_ad'
  AND TABLE_NAME IN (
    'tblAgentLoginStatus', 'tblCallDataRecords', 'tblCollectionResult',
    'tblCollections', 'tblCollectionTask', 'tblCustomerId',
    'tblUserLogs', 'tblUserReleases'
  )
  AND COLUMN_NAME IN (
    'calldate', 'createdTimestamp', 'createdTimeStamp', 'markedTimestamp',
    'inTimeStamp', 'outTimeStamp', 'updatedTimestamp', 'updatedTimeStamp',
    'datestamp', 'timestamp'
  )
ORDER BY TABLE_NAME, COLUMN_NAME;

SELECT '════════════════════════════════════════════════════════════════' AS '';
SELECT '  Cek selesai. Semua baris bertanda FAIL harus diperbaiki       ' AS '';
SELECT '  sebelum menyalakan Debezium connector.                        ' AS '';
SELECT '                                                                 ' AS '';
SELECT '  Langkah berikutnya (jika semua PASS):                         ' AS '';
SELECT '    make up       # nyalakan Kafka Connect + ClickHouse         ' AS '';
SELECT '    make register # daftarkan Debezium connector                ' AS '';
SELECT '════════════════════════════════════════════════════════════════' AS '';
