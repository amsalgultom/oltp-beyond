-- ─────────────────────────────────────────────────────────────────────────────
--  DDL REFERENSI — prod_5_smg_mirror_ad (MariaDB 5.5.60)
--  File ini adalah REFERENSI SKEMA untuk ClickHouse mapping & dokumentasi.
--  Ini bukan DDL aktual dari server prod — sesuaikan dengan output
--  SHOW CREATE TABLE <nama_tabel>; dari server asli jika ada perbedaan.
--
--  Pipeline: 8 tabel (tblCustomerId_copy DIKECUALIKAN)
-- ─────────────────────────────────────────────────────────────────────────────

CREATE DATABASE IF NOT EXISTS `prod_5_smg_mirror_ad`
  CHARACTER SET latin1
  COLLATE latin1_swedish_ci;

USE `prod_5_smg_mirror_ad`;

-- ─────────────────────────────────────────────────────────────────────────────
--  1. tblAgentLoginStatus
--     Status login agent saat ini (dimension, sering di-update)
--     PK: markedBy  |  CDC ordering: datestamp + timestamp
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `tblAgentLoginStatus` (
  `markedBy`   VARCHAR(50)  NOT NULL,        -- ID / username agent (PK; tipe bervariasi di prod)
  `state`      VARCHAR(10)  DEFAULT '0',     -- '0'=offline, '1'=online, '2'=break
  `datestamp`  DATE         DEFAULT NULL,
  `timestamp`  TIME         DEFAULT NULL,
  `extension`  VARCHAR(20)  DEFAULT NULL,    -- nomor ekstensi telepon
  `ipAddress`  VARCHAR(50)  DEFAULT NULL,
  PRIMARY KEY (`markedBy`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

-- ─────────────────────────────────────────────────────────────────────────────
--  2. tblCallDataRecords
--     CDR / log panggilan (fakta utama & terbesar)
--     PK: (uniqueid, calldate, dstchannel)  |  CDC ordering: calldate
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `tblCallDataRecords` (
  `uniqueid`      VARCHAR(64)   NOT NULL,
  `calldate`      DATETIME      NOT NULL,
  `clid`          VARCHAR(80)   DEFAULT NULL,
  `src`           VARCHAR(80)   DEFAULT NULL,    -- nomor penelepon (agent)
  `dst`           VARCHAR(80)   DEFAULT NULL,    -- nomor tujuan (nasabah)
  `dcontext`      VARCHAR(80)   DEFAULT NULL,
  `channel`       VARCHAR(80)   DEFAULT NULL,
  `dstchannel`    VARCHAR(80)   DEFAULT NULL     COMMENT 'bagian dari PK',
  `lastapp`       VARCHAR(80)   DEFAULT NULL,
  `lastdata`      VARCHAR(80)   DEFAULT NULL,
  `duration`      INT(11)       DEFAULT 0,       -- total durasi (detik)
  `billsec`       INT(11)       DEFAULT 0,       -- detik bicara (billable)
  `disposition`   VARCHAR(45)   DEFAULT NULL,    -- ANSWERED/NO ANSWER/BUSY/FAILED
  `amaflags`      INT(11)       DEFAULT NULL,
  `accountcode`   VARCHAR(20)   DEFAULT NULL,    -- kode akun / cabang
  `uniqueidOri`   VARCHAR(64)   DEFAULT NULL,
  `userfield`     VARCHAR(255)  DEFAULT NULL,
  -- Kolom enrichment (join dari tabel lain, bisa NULL)
  `contractNo`    VARCHAR(30)   DEFAULT NULL,
  `customerNo`    VARCHAR(30)   DEFAULT NULL,
  `phoneNumber`   VARCHAR(20)   DEFAULT NULL,
  `username`      VARCHAR(50)   DEFAULT NULL,    -- agent yang melakukan call
  `kodeCabang`    VARCHAR(10)   DEFAULT NULL,
  PRIMARY KEY (`uniqueid`, `calldate`, `dstchannel`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE INDEX idx_cdr_calldate   ON `tblCallDataRecords` (`calldate`);
CREATE INDEX idx_cdr_username   ON `tblCallDataRecords` (`username`);
CREATE INDEX idx_cdr_contractno ON `tblCallDataRecords` (`contractNo`);

-- ─────────────────────────────────────────────────────────────────────────────
--  3. tblCollectionResult
--     Hasil setiap call (PTP, RPC, alasan penolakan, dll.)
--     PK: uniqueId  |  CDC ordering: createdTimeStamp
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `tblCollectionResult` (
  `uniqueId`          BIGINT(20)    NOT NULL AUTO_INCREMENT,
  `noKontrak`         VARCHAR(30)   DEFAULT NULL,   -- nomor kontrak nasabah
  `callId`            VARCHAR(64)   DEFAULT NULL,   -- link ke tblCallDataRecords.uniqueid
  `agentId`           VARCHAR(50)   DEFAULT NULL,
  `classification`    VARCHAR(50)   DEFAULT NULL,   -- PTP/RPC/SKIP/WRONG NUMBER/dll
  `subClassification` VARCHAR(100)  DEFAULT NULL,
  `ptpAmount`         DECIMAL(15,2) DEFAULT NULL,   -- jumlah janji bayar
  `ptpDate`           DATE          DEFAULT NULL,   -- tanggal janji bayar
  `notes`             TEXT          DEFAULT NULL,
  `createdTimeStamp`  DATETIME      DEFAULT NULL,
  `updatedTimeStamp`  DATETIME      DEFAULT NULL,
  `kodeCabang`        VARCHAR(10)   DEFAULT NULL,
  PRIMARY KEY (`uniqueId`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE INDEX idx_cr_noKontrak ON `tblCollectionResult` (`noKontrak`);
CREATE INDEX idx_cr_created   ON `tblCollectionResult` (`createdTimeStamp`);

-- ─────────────────────────────────────────────────────────────────────────────
--  4. tblCollections
--     Snapshot collections (mirip tblCollectionResult — perhatikan duplikasi)
--     PK: collections_id  |  CDC ordering: createdTimeStamp
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `tblCollections` (
  `collections_id`    BIGINT(20)    NOT NULL AUTO_INCREMENT,
  `noKontrak`         VARCHAR(30)   DEFAULT NULL,
  `agentId`           VARCHAR(50)   DEFAULT NULL,
  `callDate`          DATETIME      DEFAULT NULL,
  `classification`    VARCHAR(50)   DEFAULT NULL,
  `subClassification` VARCHAR(100)  DEFAULT NULL,
  `ptpAmount`         DECIMAL(15,2) DEFAULT NULL,
  `ptpDate`           DATE          DEFAULT NULL,
  `callStatus`        VARCHAR(30)   DEFAULT NULL,   -- status call (disposition semantik)
  `notes`             TEXT          DEFAULT NULL,
  `createdTimeStamp`  DATETIME      DEFAULT NULL,
  `updatedTimeStamp`  DATETIME      DEFAULT NULL,
  `kodeCabang`        VARCHAR(10)   DEFAULT NULL,
  `overdue`           INT(11)       DEFAULT 0,      -- hari tunggakan saat record dibuat
  PRIMARY KEY (`collections_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE INDEX idx_col_noKontrak ON `tblCollections` (`noKontrak`);
CREATE INDEX idx_col_created   ON `tblCollections` (`createdTimeStamp`);

-- ─────────────────────────────────────────────────────────────────────────────
--  5. tblCollectionTask
--     Task/penugasan kontrak bermasalah (overdue, angsuran, kendaraan)
--     PK: id (uniqueId unik)  |  CDC ordering: createdTimestamp
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `tblCollectionTask` (
  `id`              BIGINT(20)    NOT NULL AUTO_INCREMENT,
  `uniqueId`        VARCHAR(50)   DEFAULT NULL,    -- ID tugas unik (bisa pakai sbg PK bisnis)
  `noKontrak`       VARCHAR(30)   DEFAULT NULL,
  `customerName`    VARCHAR(150)  DEFAULT NULL,
  `phoneNumber`     VARCHAR(20)   DEFAULT NULL,
  `overdue`         INT(11)       DEFAULT 0,       -- hari tunggakan
  `overdueAmount`   DECIMAL(15,2) DEFAULT NULL,    -- nominal tunggakan
  `outStdPkk`       DECIMAL(15,2) DEFAULT NULL,    -- outstanding pokok
  `angsuran`        DECIMAL(15,2) DEFAULT NULL,    -- nilai cicilan
  `vehicleType`     VARCHAR(50)   DEFAULT NULL,    -- jenis kendaraan
  `vehiclePlate`    VARCHAR(20)   DEFAULT NULL,
  `taskType`        VARCHAR(30)   DEFAULT NULL,    -- COLLECTION/SURVEY/TARIK/dll
  `priority`        INT(11)       DEFAULT 0,
  `status`          VARCHAR(30)   DEFAULT 'OPEN',
  `assignedAgent`   VARCHAR(50)   DEFAULT NULL,
  `kodeCabang`      VARCHAR(10)   DEFAULT NULL,
  `createdTimestamp` DATETIME     DEFAULT NULL,
  `updatedTimestamp` DATETIME     DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE INDEX idx_ct_noKontrak ON `tblCollectionTask` (`noKontrak`);
CREATE INDEX idx_ct_created   ON `tblCollectionTask` (`createdTimestamp`);
CREATE INDEX idx_ct_agent     ON `tblCollectionTask` (`assignedAgent`);

-- ─────────────────────────────────────────────────────────────────────────────
--  6. tblCustomerId
--     Antrian/status panggilan per kontrak (state queue penagihan)
--     PK: id (unik: priority, noKontrak)  |  CDC ordering: createdTimestamp / markedTimestamp
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `tblCustomerId` (
  `id`               BIGINT(20)    NOT NULL AUTO_INCREMENT,
  `noKontrak`        VARCHAR(30)   DEFAULT NULL,
  `customerName`     VARCHAR(150)  DEFAULT NULL,
  `phoneNumber`      VARCHAR(20)   DEFAULT NULL,
  `altPhoneNumber`   VARCHAR(20)   DEFAULT NULL,
  `callStatus`       VARCHAR(30)   DEFAULT NULL,   -- IN_QUEUE/CALLING/DONE/dll
  `priority`         INT(11)       DEFAULT 0,
  `overdue`          INT(11)       DEFAULT 0,
  `outStdPkk`        DECIMAL(15,2) DEFAULT NULL,
  `isPaid`           TINYINT(1)    DEFAULT 0,      -- 1 = sudah bayar
  `paymentDate`      DATE          DEFAULT NULL,
  `markedBy`         VARCHAR(50)   DEFAULT NULL,   -- agent yang handle
  `kodeCabang`       VARCHAR(10)   DEFAULT NULL,
  `createdTimestamp` DATETIME      DEFAULT NULL,
  `markedTimestamp`  DATETIME      DEFAULT NULL,   -- terakhir diupdate agent
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE UNIQUE INDEX idx_cid_contract_priority ON `tblCustomerId` (`noKontrak`, `priority`);
CREATE INDEX idx_cid_markedBy  ON `tblCustomerId` (`markedBy`);
CREATE INDEX idx_cid_created   ON `tblCustomerId` (`createdTimestamp`);

-- ─────────────────────────────────────────────────────────────────────────────
--  7. tblCustomerId_copy — DIKECUALIKAN TOTAL
--     Tidak masuk pipeline CDC. Tidak ada tabel ClickHouse untuk ini.
-- ─────────────────────────────────────────────────────────────────────────────
-- (sengaja tidak dibuat — hanya komentar sebagai dokumentasi keputusan)

-- ─────────────────────────────────────────────────────────────────────────────
--  8. tblUserLogs
--     Log login/logout agent (fakta sesi kerja)
--     PK: id  |  CDC ordering: inTimeStamp / outTimeStamp
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `tblUserLogs` (
  `id`           BIGINT(20)  NOT NULL AUTO_INCREMENT,
  `username`     VARCHAR(50) DEFAULT NULL,
  `ipAddress`    VARCHAR(50) DEFAULT NULL,
  `extension`    VARCHAR(20) DEFAULT NULL,
  `inTimeStamp`  DATETIME    DEFAULT NULL,    -- waktu login
  `outTimeStamp` DATETIME    DEFAULT NULL,    -- waktu logout (NULL jika masih login)
  `duration`     INT(11)     DEFAULT NULL,    -- durasi sesi (detik)
  `kodeCabang`   VARCHAR(10) DEFAULT NULL,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=latin1;

CREATE INDEX idx_ul_username ON `tblUserLogs` (`username`);
CREATE INDEX idx_ul_intime   ON `tblUserLogs` (`inTimeStamp`);

-- ─────────────────────────────────────────────────────────────────────────────
--  9. tblUserReleases
--     Rilis/penugasan user (sesi kerja, produktivitas)
--     PK: (id, hash)  |  CDC ordering: createdTimestamp / updatedTimestamp
-- ─────────────────────────────────────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS `tblUserReleases` (
  `id`               BIGINT(20)   NOT NULL AUTO_INCREMENT,
  `hash`             VARCHAR(64)  NOT NULL DEFAULT '',
  `username`         VARCHAR(50)  DEFAULT NULL,
  `releaseDate`      DATE         DEFAULT NULL,
  `totalTask`        INT(11)      DEFAULT 0,    -- jumlah task dirilis
  `totalCalled`      INT(11)      DEFAULT 0,    -- jumlah kontrak dicall
  `totalAnswered`    INT(11)      DEFAULT 0,    -- jumlah tersambung
  `totalPTP`         INT(11)      DEFAULT 0,    -- jumlah PTP berhasil
  `talkTimeSec`      INT(11)      DEFAULT 0,    -- total detik bicara
  `status`           VARCHAR(20)  DEFAULT 'ACTIVE',
  `kodeCabang`       VARCHAR(10)  DEFAULT NULL,
  `createdTimestamp` DATETIME     DEFAULT NULL,
  `updatedTimestamp` DATETIME     DEFAULT NULL,
  PRIMARY KEY (`id`, `hash`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8;

CREATE INDEX idx_ur_username ON `tblUserReleases` (`username`);
CREATE INDEX idx_ur_release  ON `tblUserReleases` (`releaseDate`);
