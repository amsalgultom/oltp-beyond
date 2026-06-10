# Data Dictionary — CDC Collection Analytics

Mapping 8 tabel sumber (MariaDB) → tipe ClickHouse.
Detail implementasi ada di `clickhouse/02_raw_tables.sql` dan `clickhouse/03_state_tables.sql`.

## Konvensi tipe

| MariaDB | ClickHouse | Catatan |
|---------|------------|---------|
| `VARCHAR` | `String` | UTF-8; waspada mojibake kolom latin1 |
| `INT` | `Int32` / `Int64` | |
| `TINYINT(1)` | `UInt8` | 0/1 flag |
| `DATETIME` | `DateTime64(3)` | parse via `parseDateTime64BestEffortOrZero` |
| `DATE` | `Date` | |
| `DECIMAL(15,2)` | `Decimal(15,2)` | Atau `Float64` jika `decimal.handling.mode=double` |
| `TEXT` | `String` | |

## Kolom CDC tambahan (dari Debezium SMT unwrap)

| Kolom | Tipe ClickHouse | Keterangan |
|-------|----------------|------------|
| `__op` | `LowCardinality(String)` | c=create, u=update, d=delete, r=read(snapshot) |
| `__ts_ms` | `Int64` | Epoch millisecond — dipakai sebagai `_version` |
| `__deleted` | `String` | 'true'/'false' — dikonversi ke `_is_deleted UInt8` |

## Tabel-tabel

### tblAgentLoginStatus → agent_login_status
PK sumber: `markedBy` | ORDER BY ClickHouse: `(marked_by)`

### tblCallDataRecords → cdr
PK sumber: `(uniqueid, calldate, dstchannel)` | ORDER BY: `(uniqueid, calldate)`

### tblCollectionResult → collection_result
PK sumber: `uniqueId` | ORDER BY: `(unique_id)`

### tblCollections → collections
PK sumber: `collections_id` | ORDER BY: `(collections_id)`

### tblCollectionTask → collection_task
PK sumber: `id` | ORDER BY: `(id)`

### tblCustomerId → customer_id
PK sumber: `id` (unik: priority+noKontrak) | ORDER BY: `(id)`

### tblUserLogs → user_logs
PK sumber: `id` | ORDER BY: `(id)`

### tblUserReleases → user_releases
PK sumber: `(id, hash)` | ORDER BY: `(id, hash)`
