# Runbook — CDC Collection Analytics

## Troubleshooting cepat

### Connector status FAILED
```bash
make logs-connect          # lihat error
make delete-connector      # hapus
make register              # daftar ulang
```

### ClickHouse tidak menerima data
1. Cek topik Kafka ada isinya (dari Kafka existing)
2. Cek `cdr_queue` bisa membaca: `SELECT count() FROM collection.cdr_queue`
3. Cek MV error di `system.query_log`

### MariaDB binlog habis / posisi hilang
- Naikkan `expire_logs_days` di server sumber
- Hapus connector, reset offset, daftar ulang dengan `snapshot.mode=schema_only`

### Snapshot terlalu lama / membebani prod
- Batalkan connector
- Gunakan `snapshot.mode=schema_only` (hanya skema, tidak baca data lama)
- Backfill historis: export CSV dari prod → `INSERT INTO <tabel>_raw`
