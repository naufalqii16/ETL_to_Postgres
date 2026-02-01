# ETL Monthly Reach to PostgreSQL

Airflow ETL pipeline yang ngambil data dari CSV lokal, lalu nge-load hasilnya ke PostgreSQL.

## Struktur Folder

```
├── dags/
│   └── load_to_postgres.py          # DAG Airflow (extract → clean → transform → load)
├── init/
│   ├── 01_create_tables.sql         # Schema raw tables
│   └── 02_load_data.sql             # Load CSV ke raw tables via COPY
├── data/
│   ├── mobility.csv
│   ├── campaign_logs.csv
│   └── billboard.csv
├── scripts
|   ├── billboard_generator.py
|   ├── campaign_logs_generator.py
|   ├── mobility_generator.py
├── tmp/
│   └── .gitkeep
├── docker-compose.yml
├── .env.example
└── README.md
```

## Setup & Cara Jalanin

### 1. Copy `.env`

```bash
cp .env.example .env
```

Edit `.env` atau tetap menggunakan default dari .env.example.

---

### 2. Jalankan Docker Compose

```bash
docker-compose up -d
```

Tunggu sampai semua container `healthy`. Bisa cek status-nya:

```bash
docker-compose ps
```

Pastiin postgres, redis, dan semua airflow services statusnya `healthy` atau `running`.

---

### 3. Verifikasi Raw Data di PostgreSQL

Sebelum menjalankan DAG, cek dulu bahwa init script sudah berhasil bikin tabel dan load data-nya:

```bash
docker exec -it etl_to_postgres-postgres-1 psql -U airflow -d airflow
```

Di dalam psql, jalanin query berikut untuk cek raw data:

```sql
-- Cek tabel billboard
SELECT * FROM billboard_inventory LIMIT 5;

-- Cek tabel campaign logs
SELECT * FROM campaign_logs LIMIT 5;

-- Cek tabel mobility events
SELECT * FROM mobility_events LIMIT 5;

-- Pastiin tabel monthly_reach BELUM ada
SELECT * FROM monthly_reach;
-- Harapannya: ERROR relation "monthly_reach" does not exist
```

Kalau semua raw table ada dan `monthly_reach` belum ada

---
### 4. Jalankan Query SQL yang merupakan jawaban dari pertanyaan di soal sql

Semua jawaban terdapat pada file **`answers_sql_analytics.sql`**. Setiap query dapat dicoba di dalam docker exec seperti pada step nomor 3.

---
### 5. Jalankan DAG di Airflow

Buka browser ke:

```
http://localhost:8080
```

Login dengan:
- **Username**: `airflow`
- **Password**: `airflow`

Cari DAG **`load_monthly_reach_to_postgres`**, toggle ON kalau masih pause, lalu trigger manually atau tunggu schedule-nya jalan.

Pastiin semua 4 task (`extract_all` → `clean_all` → `compute_monthly_reach` → `load_to_postgres`) statusnya **green (success)**.

---

### 6. Verifikasi Hasil di PostgreSQL

Setelah DAG sukses, masuk lagi ke psql:

```bash
docker exec -it etl_to_postgres-postgres-1 psql -U airflow -d airflow
```

Cek tabel `monthly_reach` yang baru terbentuk:

```sql
SELECT * FROM monthly_reach LIMIT 10;
```
Jika tabel **`monthly_reach`** dapat diquery, berarti proses ETL telah berhasil.