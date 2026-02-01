-- 1. Daily Reach
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

-- 2. Monthly Reach
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

-- 3. Population Penetration Rate
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

-- 4a. 
-- TOP 5 rank by reach (overall)
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

-- TOP 5 rank by reach (monthly)
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


-- 4b.
-- TOP 5 by Cost efficiency (Overall)
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


-- TOP 5 by Cost efficiency (Monthly)
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


-- 5. Calculate audience overlap between 2 billboards
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

-- For validation no. 5
SELECT device_id AS overlapping_devices
FROM (
  SELECT DISTINCT device_id FROM campaign_logs WHERE billboard_id = 'BB020'
  INTERSECT
  SELECT DISTINCT device_id FROM campaign_logs WHERE billboard_id = 'BB071'
);