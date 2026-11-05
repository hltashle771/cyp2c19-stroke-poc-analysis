-- EXTENDED SCORING (v2). A hypothesis layer on top of the workbook model (v1). Nothing in v1 is changed.
-- v2 adds two master fields the workbook never used to the time-sensitivity component:
--   * how quickly TIA patients are seen (inpatient and outpatient timescale)
--   * how many days a week the TIA clinic runs
-- Demand, POC suitability and readiness are unchanged. All bands and weights below are JUDGEMENT, not evidence.

-- 1. Scoring bands (editable: change a number here and rebuild)
CREATE TABLE dim_timescale_band (timescale TEXT PRIMARY KEY, band_score REAL NOT NULL, note TEXT);
INSERT INTO dim_timescale_band VALUES
 ('The same day (7 days a week)',100,'seen and decided same day, every day: a lab result may arrive after the decision'),
 ('The same day (5 days a week)', 80,'same day on weekdays only'),
 ('The next day',                 60,''),
 ('The next weekday',             60,''),
 ('Within a week',                30,''),
 ('Within a month',               10,'judgement: not in the original draft'),
 ('Longer than a month',           0,'');
CREATE TABLE dim_clinic_days_band (clinic_days INTEGER PRIMARY KEY, band_score REAL NOT NULL);
INSERT INTO dim_clinic_days_band VALUES (0,0),(1,10),(2,25),(3,40),(4,55),(5,70),(6,85),(7,100);
-- Sub-weights inside time-sensitivity. v1_equivalent reproduces the workbook (70% stay, 30% TIA wait) and is the regression test.
CREATE TABLE dim_ts_weight (variant TEXT PRIMARY KEY, w_stay REAL, w_tia_wait REAL, w_tia_timescale REAL, w_clinic_days REAL,
  CHECK (ABS(w_stay + w_tia_wait + w_tia_timescale + w_clinic_days - 1) < 1e-9));
INSERT INTO dim_ts_weight VALUES ('v1_equivalent',0.7,0.3,0.0,0.0),('v2_extended',0.5,0.2,0.2,0.1),
 ('v2_light',0.6,0.25,0.1,0.05),       -- sensitivity: new fields count for less
 ('v2_heavy',0.3,0.2,0.3,0.2),         -- sensitivity: new fields count for more
 ('v2_no_clinic_days',0.5,0.2,0.3,0.0); -- sensitivity: drops clinic days (the 'no clinic = 0' judgement) entirely

-- 2. Component scores per service. Missing = neutral 50 (never low), except 'no TIA clinic' which scores 0 on clinic days.
CREATE TABLE v2_components AS
SELECT f.service_id, f.stay_score, f.tia_speed_score,
  (SELECT AVG(b.band_score) FROM dim_timescale_band b
     WHERE b.timescale IN (m.tia_inpatient_timescale, m.tia_outpatient_timescale)) AS timescale_avg_raw,
  m.tia_clinic_flag, m.tia_clinic_days_week
FROM fact_score f JOIN v_master_clean m USING(service_id);
ALTER TABLE v2_components ADD COLUMN timescale_score REAL;
ALTER TABLE v2_components ADD COLUMN clinic_days_score REAL;
UPDATE v2_components SET timescale_score = COALESCE(timescale_avg_raw, 50);
-- Inpatient and outpatient timescales are averaged when both exist; if only one exists, that one is used.
UPDATE v2_components SET clinic_days_score = CASE
  WHEN tia_clinic_flag = 0 THEN 0
  WHEN tia_clinic_days_week IS NULL THEN 50
  ELSE (SELECT band_score FROM dim_clinic_days_band WHERE clinic_days = CAST(v2_components.tia_clinic_days_week AS INTEGER)) END;

-- 3. Time-sensitivity under each weighting variant, then lens scores and ranks (same lens weights, same tiebreak as v1).
CREATE TABLE v2_time_sensitivity AS
SELECT w.variant, c.service_id,
       w.w_stay*c.stay_score + w.w_tia_wait*c.tia_speed_score + w.w_tia_timescale*c.timescale_score + w.w_clinic_days*c.clinic_days_score AS time_sens
FROM v2_components c CROSS JOIN dim_ts_weight w;

CREATE TABLE v2_score AS
WITH base AS (
  SELECT t.variant, l.lens_id, l.lens_name, f.service_id,
         l.w_demand*f.demand_score + l.w_time_sensitivity*t.time_sens
         + l.w_poc_suitability*f.poc_suitability_score + l.w_readiness*f.readiness_score + cen.tests/1e8 AS score
  FROM v2_time_sensitivity t
  JOIN fact_score f ON f.service_id = t.service_id
  JOIN dim_service s ON s.service_id = f.service_id AND s.greenfield_flag = 1
  JOIN fact_scenario cen ON cen.service_id = f.service_id AND cen.scenario = 'Central'
  CROSS JOIN dim_lens l
  WHERE f.demand_score IS NOT NULL)
SELECT variant, lens_id, lens_name, service_id, score,
       RANK() OVER (PARTITION BY variant, lens_id ORDER BY score DESC) AS rnk
FROM base;

-- Weighting sensitivity: for each variant, how many of the v1 top 10 / top 25 stay, and where Priority A lands (Balanced lens).
CREATE VIEW v_variant_sensitivity AS
SELECT v.variant,
  SUM(CASE WHEN f.rank_balanced<=10 AND v.rnk<=10 THEN 1 ELSE 0 END) AS top10_kept,
  SUM(CASE WHEN f.rank_balanced<=25 AND v.rnk<=25 THEN 1 ELSE 0 END) AS top25_kept,
  SUM(CASE WHEN s.stage2_priority='A' AND v.rnk<=25 THEN 1 ELSE 0 END) AS priority_a_in_top25,
  MAX(ABS(f.rank_balanced - v.rnk)) AS max_move
FROM v2_score v JOIN fact_score f USING(service_id) JOIN dim_service s USING(service_id)
WHERE v.lens_id = 1 GROUP BY v.variant;

-- 4. Side-by-side: v1 workbook rank vs v2 rank, per lens. Positive move = rises under v2.
CREATE VIEW v_v1_v2_rank AS
SELECT s.service_id, s.service_name, s.stage2_priority, f.category,
       l.lens_name, CASE l.lens_id WHEN 1 THEN f.rank_balanced WHEN 2 THEN f.rank_volume ELSE f.rank_fit END AS rank_v1,
       v.rnk AS rank_v2,
       (CASE l.lens_id WHEN 1 THEN f.rank_balanced WHEN 2 THEN f.rank_volume ELSE f.rank_fit END) - v.rnk AS places_gained,
       c.timescale_score, c.clinic_days_score, c.stay_score, c.tia_speed_score
FROM v2_score v
JOIN dim_lens l USING(lens_id)
JOIN dim_service s USING(service_id)
JOIN fact_score f USING(service_id)
JOIN v2_components c USING(service_id)
WHERE v.variant = 'v2_extended';

-- 5. Does the robust core survive? Same 4,000 weight draws, v2 time-sensitivity.
CREATE TABLE robust_draw_rank_v2 AS
WITH sc AS (
  SELECT f.service_id, f.demand_score, t.time_sens, f.poc_suitability_score, f.readiness_score, cen.tests
  FROM fact_score f
  JOIN v2_time_sensitivity t ON t.service_id = f.service_id AND t.variant = 'v2_extended'
  JOIN dim_service s ON s.service_id = f.service_id AND s.greenfield_flag = 1
  JOIN fact_scenario cen ON cen.service_id = f.service_id AND cen.scenario = 'Central'
  WHERE f.demand_score IS NOT NULL),
scored AS (
  SELECT d.set_name, d.draw_id, sc.service_id,
         d.w_demand*sc.demand_score + d.w_time_sensitivity*sc.time_sens
         + d.w_poc_suitability*sc.poc_suitability_score + d.w_readiness*sc.readiness_score + sc.tests/1e8 AS score
  FROM weight_draw d CROSS JOIN sc)
SELECT set_name, draw_id, service_id, RANK() OVER (PARTITION BY set_name, draw_id ORDER BY score DESC) AS rk FROM scored;
CREATE TABLE robustness_v2 AS
SELECT set_name, service_id, AVG(CASE WHEN rk<=10 THEN 1.0 ELSE 0 END) AS top10_rate, AVG(CASE WHEN rk<=25 THEN 1.0 ELSE 0 END) AS top25_rate,
       AVG(rk) AS mean_rank FROM robust_draw_rank_v2 GROUP BY set_name, service_id;
DROP TABLE robust_draw_rank_v2;  -- 376k rows, only needed to build robustness_v2

CREATE VIEW v_robust_v1_v2 AS
SELECT a.set_name, s.service_id, s.service_name, s.stage2_priority,
       a.top25_rate AS top25_v1, b.top25_rate AS top25_v2, b.top25_rate - a.top25_rate AS change_top25,
       a.mean_rank AS mean_rank_v1, b.mean_rank AS mean_rank_v2
FROM robustness a JOIN robustness_v2 b USING(set_name, service_id) JOIN dim_service s USING(service_id);

-- 6. Test: the v2 engine, when told to use v1's sub-weights, must reproduce the workbook exactly.
INSERT INTO test_results SELECT 'v2 engine, v1 sub-weights: time-sensitivity max abs diff vs workbook', 0, MAX(ABS(t.time_sens - f.time_sensitivity_score)), 1e-9, 0
  FROM v2_time_sensitivity t JOIN fact_score f USING(service_id) WHERE t.variant='v1_equivalent';
INSERT INTO test_results SELECT 'v2 engine, v1 sub-weights: '||lens_name||' rank mismatches vs workbook', 0,
  SUM(CASE WHEN v.rnk <> CASE v.lens_id WHEN 1 THEN f.rank_balanced WHEN 2 THEN f.rank_volume ELSE f.rank_fit END THEN 1 ELSE 0 END), 0, 0
  FROM v2_score v JOIN fact_score f USING(service_id) WHERE v.variant='v1_equivalent' GROUP BY v.lens_id, v.lens_name;
INSERT INTO test_results SELECT 'v2 scored services per lens', 94, COUNT(*), 0, 0 FROM v2_score WHERE variant='v2_extended' AND lens_id=1;
INSERT INTO test_results SELECT 'timescale texts with no band (unmapped)', 0, COUNT(*), 0, 0
  FROM (SELECT tia_inpatient_timescale AS t FROM v_master_clean UNION SELECT tia_outpatient_timescale FROM v_master_clean)
  WHERE t IS NOT NULL AND t NOT IN (SELECT timescale FROM dim_timescale_band);
INSERT INTO test_results SELECT 'v2 time-sensitivity inside 0-100 (violations)', 0, COUNT(*), 0, 0 FROM v2_time_sensitivity WHERE time_sens < 0 OR time_sens > 100;
INSERT INTO test_results SELECT 'v2 clinic-days score missing where a clinic exists (non-neutral gaps)', 0, COUNT(*), 0, 0
  FROM v2_components WHERE clinic_days_score IS NULL;
UPDATE test_results SET pass = CASE WHEN ABS(expected - actual) <= MAX(tolerance, 0) AND (tolerance > 0 OR expected = actual OR ABS(expected-actual) < 1e-9) THEN 1 ELSE 0 END;
