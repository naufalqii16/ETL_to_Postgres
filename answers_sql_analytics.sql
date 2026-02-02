-- ======================================================================================================================
-- 1. Daily Reach
-- ======================================================================================================================
-- asumsi konteks: Reach berarti exposure dari entitas unique, berbeda dengan impression yang hanya menghitung jangkauan
-- nya saja tanpa memedulikan entitas tersebut sudah pernah muncul atau belum
-- dari asumsi tersebut, untuk menghitung daily reach, device id perlu di-distinct terlebih dahulu sebelum di-count
-- setelah itu di group by dengan billboard_id dan date(exposure_time) untuk mendapatkan reach daily tiap billboard pada fungsi aggregate count nya
-- left join di bawah digunakan hanya untuk mengambil nama dari billboard nya
with daily_reach as (
SELECT
  cl.billboard_id,
  DATE(cl.exposure_time) AS date,
  COUNT(DISTINCT cl.device_id) AS daily_reach
FROM campaign_logs cl
GROUP BY cl.billboard_id, DATE(cl.exposure_time)
)
select dr.billboard_id, bb.billboard_name, dr.date, dr.daily_reach from daily_reach dr
left join billboard_inventory bb on bb.billboard_id = dr.billboard_id
order by dr.date asc, dr.daily_reach desc;

-- ======================================================================================================================
-- 2. Monthly Reach
-- ======================================================================================================================
-- mirip dengan daily reach, bedanya ini dilakukan group by pada month
SELECT
  cl.billboard_id,
  DATE_TRUNC('month', cl.exposure_time) AS month,
  COUNT(DISTINCT cl.device_id) AS monthly_reach
FROM campaign_logs cl
GROUP BY
  cl.billboard_id,
  DATE_TRUNC('month', cl.exposure_time)
ORDER BY
  month ASC,
  monthly_reach DESC;

-- ======================================================================================================================
-- 3. Population Penetration Rate
-- ======================================================================================================================
-- population penetration rate berarti rate populasi di suatu wilayah yang terekspose oleh suatu iklan, dalam hal ini bentuk iklannya OOH.
-- formula diketahui: monthly_reach / total_population
-- asumsi jumlah populasi: 2,340,000
-- dicari terlebih dahulu monthly_reach nya seperti query pada nomor 2, lalu dibagi dengan total_population diketahui.
WITH monthly AS (
  SELECT
    cl.billboard_id,
    DATE_TRUNC('month', cl.exposure_time) AS month,
    COUNT(DISTINCT cl.device_id) AS monthly_reach
  FROM campaign_logs cl
  GROUP BY cl.billboard_id, DATE_TRUNC('month', cl.exposure_time)
)
SELECT
  *,
  monthly_reach::NUMERIC / 2340000 AS population_penetration_rate
FROM monthly
ORDER BY month ASC, monthly_reach DESC;
-- ======================================================================================================================
-- 4a. 
-- TOP 5 rank by reach (overall)
-- ======================================================================================================================
-- overall reach berarti berapa banyak entitas unique yang terpapar oleh campaign di setiap billboard untuk keseluruhan data
-- setelah dapat overal_reach nya, dilakukan rank menggunakan window function
-- setelah itu, diambil hanya 5 teratas
with overall_reach as (
select billboard_id, count(distinct device_id) as overall_reach from campaign_logs cl
group by billboard_id
),
final_rank as (
select billboard_id, overall_reach, rank() over (order by overall_reach desc) as rank_by_reach
from overall_reach
)
select * from final_rank
where rank_by_reach <=5;
-- ======================================================================================================================
-- TOP 5 rank by reach (monthly)
-- ======================================================================================================================
-- hampir sama dengan sebelumnya, bedanya query ini untuk mengetahui TOP 5 secara monthly
-- rank dihitung berdasarkan monthly_reach tiap billboard setelah monthly_reach didapatkan
-- partition menggunakan month agar dapat memperoleh top 5 di setiap bulannya
WITH monthly AS (
  SELECT
    cl.billboard_id,
    DATE_TRUNC('month', cl.exposure_time) AS month,
    COUNT(DISTINCT cl.device_id) AS monthly_reach
  FROM campaign_logs cl
  GROUP BY
    cl.billboard_id,
    DATE_TRUNC('month', cl.exposure_time)
),
final_rank AS (
  SELECT billboard_id, month, monthly_reach,
    RANK() OVER (
      PARTITION BY month
      ORDER BY monthly_reach DESC
    ) AS rank_by_reach
  FROM monthly
)
SELECT billboard_id, month, monthly_reach, rank_by_reach FROM final_rank
WHERE rank_by_reach <= 5
ORDER BY month ASC, rank_by_reach ASC;

-- ======================================================================================================================
-- 4b.
-- TOP 5 by Cost efficiency (Overall)
-- ======================================================================================================================
-- di dalam tabel billboard, terdapat kolom daily_cost
-- karena cost bersifat daily, maka perhitungan cost efficiency dipengaruhi oleh daily_cost * total active days sebagai total cost yang dikeluarkan, dan billboard reach sebagai keuntungan
-- untuk cost efficiency overall ini, active days nya dihitung dari maximum exposure_time dikurangi dengan minimum exposure_time + 1
-- 2 CTE pertama dipakai untuk mendapatkan total active_days dan overall_reach
-- CTE ketiga dipakai untuk menghitung total cost
-- CTE terakhir dipakai untuk melakukan ranking dengan ketentuan:
--  => order by ascending karena semakin kecil cost nya, semakin bagus
--  => NULLIF dipakai untuk menghindari pembagi nol yang terjadi saat overall_reach bernilai nol.
WITH active_period AS (
  SELECT
    billboard_id,
    MIN(exposure_time)::DATE AS start_date,
    MAX(exposure_time)::DATE AS end_date,
    (MAX(exposure_time)::DATE - MIN(exposure_time)::DATE) + 1 AS active_days
  FROM campaign_logs
  GROUP BY billboard_id
),
overall_reach AS (
  SELECT
    billboard_id,
    COUNT(DISTINCT device_id) AS overall_reach
  FROM campaign_logs
  GROUP BY billboard_id
),
overall_cost AS (
  SELECT
    ap.billboard_id,
    ap.active_days * bb.daily_cost AS overall_cost
  FROM active_period ap
  JOIN billboard_inventory bb
    ON ap.billboard_id = bb.billboard_id
),
overall_rank AS (
  SELECT
    r.billboard_id,
    r.overall_reach,
    c.overall_cost,
    c.overall_cost::NUMERIC / NULLIF(r.overall_reach, 0) AS cost_per_reach,
    RANK() OVER (
      ORDER BY c.overall_cost::NUMERIC / NULLIF(r.overall_reach, 0) ASC
    ) AS rank_by_cost_efficiency
  FROM overall_reach r
  JOIN overall_cost c
    ON r.billboard_id = c.billboard_id
)
SELECT
  billboard_id,
  overall_reach,
  overall_cost,
  cost_per_reach,
  rank_by_cost_efficiency
FROM overall_rank
WHERE rank_by_cost_efficiency <= 5
ORDER BY rank_by_cost_efficiency ASC;

-- ======================================================================================================================
-- TOP 5 by Cost efficiency (Monthly)
-- ======================================================================================================================
-- hampir sama dengan sebelumnya, bedanya semua parameter dihitung monthly. active_days dianggap sama di 30 hari, reach menggunakan monthly_reach
-- tiap bulan memiliki rank top 5 nya masing-masing
WITH monthly_reach AS (
  SELECT
    billboard_id,
    DATE_TRUNC('month', exposure_time) AS month,
    COUNT(DISTINCT device_id) AS monthly_reach
  FROM campaign_logs
  GROUP BY billboard_id, DATE_TRUNC('month', exposure_time)
),
base AS (
  SELECT
    mr.billboard_id, mr.month, mr.monthly_reach, bb.daily_cost * 30 AS monthly_cost,
    (bb.daily_cost * 30)::NUMERIC / NULLIF(mr.monthly_reach, 0) AS cost_per_reach
  FROM monthly_reach mr
  JOIN billboard_inventory bb ON mr.billboard_id = bb.billboard_id
),
monthly_rank AS (
  SELECT
    billboard_id, month, monthly_reach, monthly_cost, cost_per_reach,
    RANK() OVER (
      PARTITION BY month
      ORDER BY cost_per_reach ASC
    ) AS rank_by_cost_efficiency
  FROM base
)
SELECT
  billboard_id, month, monthly_reach, monthly_cost, cost_per_reach, rank_by_cost_efficiency
FROM monthly_rank
WHERE rank_by_cost_efficiency <= 5
ORDER BY month ASC, rank_by_cost_efficiency ASC;

-- ======================================================================================================================
-- 5. Calculate audience overlap between 2 billboards
-- ======================================================================================================================
-- satu device dapat muncul ke beberapa billboard
-- CTE digunakan untuk mencari setiap billboard pernah terekspose oleh device_id apa saja
-- CTE tersebut kemudian dilakukan self join agar mendapatkan 2 billboard yang pernah diekspose ke device yang sama
-- ekspresi a.billboard_id < b.billboard_id pada join berguna agar billboard BB020 x BB071 dan BB071 x BB020 dihitung sekali saja
with billboard_devices as (
select DISTINCT billboard_id, device_id from campaign_logs
)
select 
	a.billboard_id as billboard_a,
	b.billboard_id as billboard_b,
	count(distinct a.device_id) as overlapping_devices
from billboard_devices a
join billboard_devices b on a.device_id = b.device_id and a.billboard_id < b.billboard_id
group by a.billboard_id, b.billboard_id
order by overlapping_devices desc;

-- ======================================================================================================================
-- Validation for question no. 5
SELECT device_id AS overlapping_devices
FROM (
  SELECT DISTINCT device_id FROM campaign_logs WHERE billboard_id = 'BB020'
  INTERSECT
  SELECT DISTINCT device_id FROM campaign_logs WHERE billboard_id = 'BB071'
);