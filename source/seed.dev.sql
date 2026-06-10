-- ─────────────────────────────────────────────────────────────────────────────
--  seed.dev.sql
--  Data dummy untuk MariaDB stand-in (profile "dev").
--  HANYA dipakai di lingkungan lokal — JANGAN jalankan di prod.
--
--  Cara pakai: make seed-dev   (atau otomatis saat make up-dev)
--
--  Skenario yang di-cover:
--    - Agent login/logout
--    - CDR: ANSWERED, NO ANSWER, BUSY, FAILED
--    - Collection result: PTP, RPC, skip
--    - Collection task: berbagai bucket overdue
--    - Customer queue: IN_QUEUE, CALLING, DONE, PAID
--    - User logs sesi kerja
--    - User releases harian
-- ─────────────────────────────────────────────────────────────────────────────

USE `prod_5_smg_mirror_ad`;

-- ─── Grant user debezium di stand-in ─────────────────────────────────────────
-- (Untuk prod, grant dilakukan oleh DBA di server asli; lihat §4 PLAN.md)
CREATE USER IF NOT EXISTS 'debezium'@'%' IDENTIFIED BY 'debezium_dev_password';
GRANT SELECT, RELOAD, SHOW DATABASES, REPLICATION SLAVE, REPLICATION CLIENT
  ON *.* TO 'debezium'@'%';
FLUSH PRIVILEGES;

-- ─────────────────────────────────────────────────────────────────────────────
--  1. tblAgentLoginStatus — 5 agent, status campuran
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO `tblAgentLoginStatus` (`markedBy`, `state`, `datestamp`, `timestamp`, `extension`, `ipAddress`) VALUES
  ('agent01', '1', CURDATE(), CURTIME(), '101', '10.0.0.11'),
  ('agent02', '1', CURDATE(), CURTIME(), '102', '10.0.0.12'),
  ('agent03', '2', CURDATE(), CURTIME(), '103', '10.0.0.13'),   -- break
  ('agent04', '0', DATE_SUB(CURDATE(),INTERVAL 1 DAY), '17:30:00', '104', '10.0.0.14'),  -- offline
  ('agent05', '1', CURDATE(), CURTIME(), '105', '10.0.0.15')
ON DUPLICATE KEY UPDATE
  `state`=VALUES(`state`), `datestamp`=VALUES(`datestamp`), `timestamp`=VALUES(`timestamp`);

-- ─────────────────────────────────────────────────────────────────────────────
--  2. tblCallDataRecords — CDR beragam disposition
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO `tblCallDataRecords`
  (`uniqueid`,`calldate`,`src`,`dst`,`dstchannel`,`duration`,`billsec`,`disposition`,`accountcode`,`contractNo`,`customerNo`,`phoneNumber`,`username`,`kodeCabang`)
VALUES
  ('cdr-001', DATE_SUB(NOW(),INTERVAL 55 MINUTE), '101','0811111001','SIP/101-000001', 95,  78, 'ANSWERED',  'SMG','KTR-001001','CST-001','0811111001','agent01','SMG'),
  ('cdr-002', DATE_SUB(NOW(),INTERVAL 52 MINUTE), '102','0811111002','SIP/102-000002', 35,   0, 'NO ANSWER', 'SMG','KTR-001002','CST-002','0811111002','agent02','SMG'),
  ('cdr-003', DATE_SUB(NOW(),INTERVAL 48 MINUTE), '101','0811111003','SIP/101-000003',128, 112, 'ANSWERED',  'SMG','KTR-001003','CST-003','0811111003','agent01','SMG'),
  ('cdr-004', DATE_SUB(NOW(),INTERVAL 45 MINUTE), '103','0811111004','SIP/103-000004', 18,   0, 'BUSY',      'SMG','KTR-001004','CST-004','0811111004','agent03','SMG'),
  ('cdr-005', DATE_SUB(NOW(),INTERVAL 40 MINUTE), '102','0811111005','SIP/102-000005', 65,  55, 'ANSWERED',  'SMG','KTR-001005','CST-005','0811111005','agent02','SMG'),
  ('cdr-006', DATE_SUB(NOW(),INTERVAL 35 MINUTE), '105','0811111006','SIP/105-000006', 12,   0, 'FAILED',    'SMG','KTR-001006','CST-006','0811111006','agent05','SMG'),
  ('cdr-007', DATE_SUB(NOW(),INTERVAL 30 MINUTE), '101','0811111007','SIP/101-000007',200, 185, 'ANSWERED',  'SMG','KTR-001007','CST-007','0811111007','agent01','SMG'),
  ('cdr-008', DATE_SUB(NOW(),INTERVAL 25 MINUTE), '104','0811111008','SIP/104-000008', 30,   0, 'NO ANSWER', 'SMG','KTR-001008','CST-008','0811111008','agent04','SMG'),
  ('cdr-009', DATE_SUB(NOW(),INTERVAL 20 MINUTE), '102','0811111009','SIP/102-000009', 88,  75, 'ANSWERED',  'SMG','KTR-001009','CST-009','0811111009','agent02','SMG'),
  ('cdr-010', DATE_SUB(NOW(),INTERVAL 15 MINUTE), '105','0811111010','SIP/105-000010',145, 130, 'ANSWERED',  'SMG','KTR-001010','CST-010','0811111010','agent05','SMG'),
  ('cdr-011', DATE_SUB(NOW(),INTERVAL 10 MINUTE), '101','0811111011','SIP/101-000011', 55,  42, 'ANSWERED',  'SMG','KTR-001011','CST-011','0811111011','agent01','SMG'),
  ('cdr-012', DATE_SUB(NOW(),INTERVAL  5 MINUTE), '102','0811111012','SIP/102-000012', 22,   0, 'NO ANSWER', 'SMG','KTR-001012','CST-012','0811111012','agent02','SMG'),
  -- CDR kemarin (untuk pre-agg & time travel test)
  ('cdr-101', DATE_SUB(NOW(),INTERVAL 25 HOUR), '101','0811111001','SIP/101-000101', 90,  77, 'ANSWERED',  'SMG','KTR-001001','CST-001','0811111001','agent01','SMG'),
  ('cdr-102', DATE_SUB(NOW(),INTERVAL 24 HOUR), '102','0811111002','SIP/102-000102', 40,   0, 'NO ANSWER', 'SMG','KTR-001002','CST-002','0811111002','agent02','SMG'),
  ('cdr-103', DATE_SUB(NOW(),INTERVAL 23 HOUR), '103','0811111003','SIP/103-000103',110,  98, 'ANSWERED',  'SMG','KTR-001003','CST-003','0811111003','agent03','SMG');

-- ─────────────────────────────────────────────────────────────────────────────
--  3. tblCollectionResult — hasil call: PTP, RPC, skip
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO `tblCollectionResult`
  (`noKontrak`,`callId`,`agentId`,`classification`,`subClassification`,`ptpAmount`,`ptpDate`,`notes`,`createdTimeStamp`,`kodeCabang`)
VALUES
  ('KTR-001001','cdr-001','agent01','PTP',  'FULL',    500000, DATE_ADD(CURDATE(),INTERVAL 3 DAY), 'Janji lunas minggu ini',    DATE_SUB(NOW(),INTERVAL 54 MINUTE),'SMG'),
  ('KTR-001003','cdr-003','agent01','RPC',  'CONTACT',      0, NULL,                               'Tersambung, belum ada PTP', DATE_SUB(NOW(),INTERVAL 47 MINUTE),'SMG'),
  ('KTR-001005','cdr-005','agent02','PTP',  'PARTIAL', 250000, DATE_ADD(CURDATE(),INTERVAL 7 DAY), 'Bayar sebagian dulu',       DATE_SUB(NOW(),INTERVAL 39 MINUTE),'SMG'),
  ('KTR-001007','cdr-007','agent01','RPC',  'CONTACT',      0, NULL,                               'Hubungi ulang besok',       DATE_SUB(NOW(),INTERVAL 29 MINUTE),'SMG'),
  ('KTR-001009','cdr-009','agent02','SKIP', 'REFUSAL',      0, NULL,                               'Tidak mau berbicara',       DATE_SUB(NOW(),INTERVAL 19 MINUTE),'SMG'),
  ('KTR-001010','cdr-010','agent05','PTP',  'FULL',    750000, DATE_ADD(CURDATE(),INTERVAL 5 DAY), 'Konfirmasi via WA',         DATE_SUB(NOW(),INTERVAL 14 MINUTE),'SMG'),
  ('KTR-001011','cdr-011','agent01','RPC',  'CONTACT',      0, NULL,                               'Follow up besok',           DATE_SUB(NOW(),INTERVAL  9 MINUTE),'SMG');

-- ─────────────────────────────────────────────────────────────────────────────
--  4. tblCollections — snapshot collections
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO `tblCollections`
  (`noKontrak`,`agentId`,`callDate`,`classification`,`callStatus`,`ptpAmount`,`ptpDate`,`createdTimeStamp`,`kodeCabang`,`overdue`)
VALUES
  ('KTR-001001','agent01',DATE_SUB(NOW(),INTERVAL 54 MINUTE),'PTP', 'ANSWERED',500000,DATE_ADD(CURDATE(),INTERVAL 3 DAY),DATE_SUB(NOW(),INTERVAL 54 MINUTE),'SMG', 35),
  ('KTR-001003','agent01',DATE_SUB(NOW(),INTERVAL 47 MINUTE),'RPC', 'ANSWERED',     0,NULL,                              DATE_SUB(NOW(),INTERVAL 47 MINUTE),'SMG', 62),
  ('KTR-001005','agent02',DATE_SUB(NOW(),INTERVAL 39 MINUTE),'PTP', 'ANSWERED',250000,DATE_ADD(CURDATE(),INTERVAL 7 DAY),DATE_SUB(NOW(),INTERVAL 39 MINUTE),'SMG', 12),
  ('KTR-001002','agent02',DATE_SUB(NOW(),INTERVAL 52 MINUTE),'NONE','NO ANSWER',    0,NULL,                              DATE_SUB(NOW(),INTERVAL 52 MINUTE),'SMG', 90);

-- ─────────────────────────────────────────────────────────────────────────────
--  5. tblCollectionTask — task penagihan berbagai bucket overdue
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO `tblCollectionTask`
  (`uniqueId`,`noKontrak`,`customerName`,`phoneNumber`,`overdue`,`overdueAmount`,`outStdPkk`,`angsuran`,`vehicleType`,`taskType`,`priority`,`status`,`assignedAgent`,`kodeCabang`,`createdTimestamp`)
VALUES
  ('TASK-001','KTR-001001','Budi Santoso',  '0811111001', 35, 1050000,  8500000, 500000,'MOTOR','COLLECTION',1,'OPEN',  'agent01','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR)),
  ('TASK-002','KTR-001002','Siti Rahayu',   '0811111002', 62, 1860000, 12000000, 600000,'MOBIL','COLLECTION',2,'OPEN',  'agent02','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR)),
  ('TASK-003','KTR-001003','Ahmad Fauzi',   '0811111003', 12,  360000,  5000000, 450000,'MOTOR','COLLECTION',3,'OPEN',  'agent01','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR)),
  ('TASK-004','KTR-001004','Dewi Lestari',  '0811111004', 95, 2850000, 20000000, 950000,'MOBIL','COLLECTION',1,'OPEN',  'agent03','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR)),
  ('TASK-005','KTR-001005','Eko Prasetyo',  '0811111005', 18,  540000,  6500000, 480000,'MOTOR','COLLECTION',2,'DONE',  'agent02','SMG',DATE_SUB(NOW(),INTERVAL 3 HOUR)),
  ('TASK-006','KTR-001006','Fitri Handayani','0811111006',45, 1350000,  9000000, 520000,'MOTOR','COLLECTION',2,'OPEN',  'agent05','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR)),
  ('TASK-007','KTR-001007','Gunawan Susilo', '0811111007',75, 2250000, 15000000, 700000,'MOBIL','COLLECTION',1,'OPEN',  'agent01','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR)),
  ('TASK-008','KTR-001008','Hani Wijaya',    '0811111008',28,  840000,  7200000, 510000,'MOTOR','COLLECTION',3,'OPEN',  'agent04','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR)),
  ('TASK-009','KTR-001009','Irfan Maulana',  '0811111009',55, 1650000, 11000000, 600000,'MOBIL','COLLECTION',2,'OPEN',  'agent02','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR)),
  ('TASK-010','KTR-001010','Juwita Sari',    '0811111010',10,  300000,  4500000, 430000,'MOTOR','COLLECTION',3,'DONE',  'agent05','SMG',DATE_SUB(NOW(),INTERVAL 3 HOUR)),
  ('TASK-011','KTR-001011','Kurniawan',      '0811111011',120,3600000, 25000000,1100000,'MOBIL','COLLECTION',1,'OPEN',  'agent01','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR)),
  ('TASK-012','KTR-001012','Laras Puspita',  '0811111012', 88,2640000, 18000000, 880000,'MOBIL','COLLECTION',1,'OPEN',  'agent02','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR));

-- ─────────────────────────────────────────────────────────────────────────────
--  6. tblCustomerId — antrian panggilan
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO `tblCustomerId`
  (`noKontrak`,`customerName`,`phoneNumber`,`callStatus`,`priority`,`overdue`,`outStdPkk`,`isPaid`,`paymentDate`,`markedBy`,`kodeCabang`,`createdTimestamp`,`markedTimestamp`)
VALUES
  ('KTR-001001','Budi Santoso',   '0811111001','DONE',   1, 35,  8500000,0,NULL,       'agent01','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),DATE_SUB(NOW(),INTERVAL 53 MINUTE)),
  ('KTR-001002','Siti Rahayu',    '0811111002','IN_QUEUE',2, 62, 12000000,0,NULL,       NULL,     'SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),NULL),
  ('KTR-001003','Ahmad Fauzi',    '0811111003','DONE',   3, 12,  5000000,0,NULL,       'agent01','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),DATE_SUB(NOW(),INTERVAL 46 MINUTE)),
  ('KTR-001004','Dewi Lestari',   '0811111004','IN_QUEUE',1, 95, 20000000,0,NULL,       NULL,     'SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),NULL),
  ('KTR-001005','Eko Prasetyo',   '0811111005','PAID',   2, 18,  6500000,1,CURDATE(),  'agent02','SMG',DATE_SUB(NOW(),INTERVAL 3 HOUR),DATE_SUB(NOW(),INTERVAL 38 MINUTE)),
  ('KTR-001006','Fitri Handayani','0811111006','IN_QUEUE',2, 45,  9000000,0,NULL,       NULL,     'SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),NULL),
  ('KTR-001007','Gunawan Susilo', '0811111007','CALLING',1, 75, 15000000,0,NULL,       'agent01','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),DATE_SUB(NOW(),INTERVAL 2 MINUTE)),
  ('KTR-001008','Hani Wijaya',    '0811111008','IN_QUEUE',3, 28,  7200000,0,NULL,       NULL,     'SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),NULL),
  ('KTR-001009','Irfan Maulana',  '0811111009','DONE',   2, 55, 11000000,0,NULL,       'agent02','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),DATE_SUB(NOW(),INTERVAL 18 MINUTE)),
  ('KTR-001010','Juwita Sari',    '0811111010','PAID',   3, 10,  4500000,1,CURDATE(),  'agent05','SMG',DATE_SUB(NOW(),INTERVAL 3 HOUR),DATE_SUB(NOW(),INTERVAL 13 MINUTE)),
  ('KTR-001011','Kurniawan',      '0811111011','CALLING',1,120, 25000000,0,NULL,       'agent01','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),DATE_SUB(NOW(),INTERVAL 1 MINUTE)),
  ('KTR-001012','Laras Puspita',  '0811111012','IN_QUEUE',1, 88, 18000000,0,NULL,       NULL,     'SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),NULL);

-- ─────────────────────────────────────────────────────────────────────────────
--  8. tblUserLogs — sesi login agent hari ini & kemarin
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO `tblUserLogs` (`username`,`ipAddress`,`extension`,`inTimeStamp`,`outTimeStamp`,`duration`,`kodeCabang`) VALUES
  ('agent01','10.0.0.11','101',DATE_FORMAT(CONCAT(DATE_SUB(CURDATE(),INTERVAL 1 DAY),' 08:00:00'),'%Y-%m-%d %H:%i:%s'),DATE_FORMAT(CONCAT(DATE_SUB(CURDATE(),INTERVAL 1 DAY),' 17:00:00'),'%Y-%m-%d %H:%i:%s'),32400,'SMG'),
  ('agent02','10.0.0.12','102',DATE_FORMAT(CONCAT(DATE_SUB(CURDATE(),INTERVAL 1 DAY),' 08:05:00'),'%Y-%m-%d %H:%i:%s'),DATE_FORMAT(CONCAT(DATE_SUB(CURDATE(),INTERVAL 1 DAY),' 17:10:00'),'%Y-%m-%d %H:%i:%s'),32700,'SMG'),
  ('agent03','10.0.0.13','103',DATE_FORMAT(CONCAT(DATE_SUB(CURDATE(),INTERVAL 1 DAY),' 08:10:00'),'%Y-%m-%d %H:%i:%s'),DATE_FORMAT(CONCAT(DATE_SUB(CURDATE(),INTERVAL 1 DAY),' 17:00:00'),'%Y-%m-%d %H:%i:%s'),32400,'SMG'),
  ('agent01','10.0.0.11','101',CONCAT(CURDATE(),' 08:00:00'),NULL,NULL,'SMG'),
  ('agent02','10.0.0.12','102',CONCAT(CURDATE(),' 08:05:00'),NULL,NULL,'SMG'),
  ('agent03','10.0.0.13','103',CONCAT(CURDATE(),' 08:10:00'),NULL,NULL,'SMG'),
  ('agent04','10.0.0.14','104',CONCAT(CURDATE(),' 08:15:00'),DATE_FORMAT(DATE_SUB(NOW(),INTERVAL 30 MINUTE),'%Y-%m-%d %H:%i:%s'),NULL,'SMG'),
  ('agent05','10.0.0.15','105',CONCAT(CURDATE(),' 08:20:00'),NULL,NULL,'SMG');

-- ─────────────────────────────────────────────────────────────────────────────
--  9. tblUserReleases — ringkasan produktivitas harian
-- ─────────────────────────────────────────────────────────────────────────────
INSERT INTO `tblUserReleases`
  (`hash`,`username`,`releaseDate`,`totalTask`,`totalCalled`,`totalAnswered`,`totalPTP`,`talkTimeSec`,`status`,`kodeCabang`,`createdTimestamp`,`updatedTimestamp`)
VALUES
  (MD5(CONCAT('agent01',DATE_SUB(CURDATE(),INTERVAL 1 DAY))),'agent01',DATE_SUB(CURDATE(),INTERVAL 1 DAY),25,22,18,6,4500,'CLOSED','SMG',DATE_SUB(NOW(),INTERVAL 25 HOUR),DATE_SUB(NOW(),INTERVAL 17 HOUR)),
  (MD5(CONCAT('agent02',DATE_SUB(CURDATE(),INTERVAL 1 DAY))),'agent02',DATE_SUB(CURDATE(),INTERVAL 1 DAY),20,18,14,4,3200,'CLOSED','SMG',DATE_SUB(NOW(),INTERVAL 25 HOUR),DATE_SUB(NOW(),INTERVAL 17 HOUR)),
  (MD5(CONCAT('agent03',DATE_SUB(CURDATE(),INTERVAL 1 DAY))),'agent03',DATE_SUB(CURDATE(),INTERVAL 1 DAY),18,15,11,3,2800,'CLOSED','SMG',DATE_SUB(NOW(),INTERVAL 25 HOUR),DATE_SUB(NOW(),INTERVAL 17 HOUR)),
  (MD5(CONCAT('agent01',CURDATE())),'agent01',CURDATE(), 8, 7, 5,2,1200,'ACTIVE','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),NOW()),
  (MD5(CONCAT('agent02',CURDATE())),'agent02',CURDATE(), 6, 5, 4,2, 900,'ACTIVE','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),NOW()),
  (MD5(CONCAT('agent05',CURDATE())),'agent05',CURDATE(), 5, 4, 3,1, 750,'ACTIVE','SMG',DATE_SUB(NOW(),INTERVAL 2 HOUR),NOW());

SELECT '>>> Seed selesai. Data dummy siap untuk dev/test.' AS '';
SELECT CONCAT('    tblAgentLoginStatus  : ', COUNT(*), ' rows') AS info FROM tblAgentLoginStatus
  UNION ALL
  SELECT CONCAT('    tblCallDataRecords   : ', COUNT(*), ' rows') FROM tblCallDataRecords
  UNION ALL
  SELECT CONCAT('    tblCollectionResult  : ', COUNT(*), ' rows') FROM tblCollectionResult
  UNION ALL
  SELECT CONCAT('    tblCollections       : ', COUNT(*), ' rows') FROM tblCollections
  UNION ALL
  SELECT CONCAT('    tblCollectionTask    : ', COUNT(*), ' rows') FROM tblCollectionTask
  UNION ALL
  SELECT CONCAT('    tblCustomerId        : ', COUNT(*), ' rows') FROM tblCustomerId
  UNION ALL
  SELECT CONCAT('    tblUserLogs          : ', COUNT(*), ' rows') FROM tblUserLogs
  UNION ALL
  SELECT CONCAT('    tblUserReleases      : ', COUNT(*), ' rows') FROM tblUserReleases;
