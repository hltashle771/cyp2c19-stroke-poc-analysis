-- A. Recompute the three lens scores and ranks from components and weights (independent of the workbook formulas).
CREATE TABLE score_recompute AS
WITH base AS (
  SELECT l.lens_id, l.lens_name, f.service_id,
         l.w_demand*f.demand_score + l.w_time_sensitivity*f.time_sensitivity_score
         + l.w_poc_suitability*f.poc_suitability_score + l.w_readiness*f.readiness_score
         + cen.tests/1e8 AS score
  FROM dim_lens l
  CROSS JOIN fact_score f
  JOIN dim_service s ON s.service_id = f.service_id AND s.greenfield_flag = 1
  JOIN fact_scenario cen ON cen.service_id = f.service_id AND cen.scenario = 'Central'
  WHERE f.demand_score IS NOT NULL)
SELECT lens_id, lens_name, service_id, score,
       RANK() OVER (PARTITION BY lens_id ORDER BY score DESC) AS rank_recomputed
FROM base;

-- B. Weight robustness. 4,000 seeded weight sets (2,000 free, 2,000 with a 5% floor per component).
-- For each service: how often is it in the top 10 / top 25, and what is its rank spread?
CREATE TABLE robust_draw_rank AS
WITH sc AS (
  SELECT f.service_id, f.demand_score, f.time_sensitivity_score, f.poc_suitability_score, f.readiness_score, cen.tests
  FROM fact_score f
  JOIN dim_service s ON s.service_id = f.service_id AND s.greenfield_flag = 1
  JOIN fact_scenario cen ON cen.service_id = f.service_id AND cen.scenario = 'Central'
  WHERE f.demand_score IS NOT NULL),
scored AS (
  SELECT d.set_name, d.draw_id, sc.service_id,
         d.w_demand*sc.demand_score + d.w_time_sensitivity*sc.time_sensitivity_score
         + d.w_poc_suitability*sc.poc_suitability_score + d.w_readiness*sc.readiness_score + sc.tests/1e8 AS score
  FROM weight_draw d CROSS JOIN sc)
SELECT set_name, draw_id, service_id,
       RANK() OVER (PARTITION BY set_name, draw_id ORDER BY score DESC) AS rk
FROM scored;
CREATE INDEX ix_rdr ON robust_draw_rank(set_name, service_id);

CREATE TABLE robustness AS
WITH ordered AS (
  SELECT set_name, service_id, rk,
         ROW_NUMBER() OVER (PARTITION BY set_name, service_id ORDER BY rk) AS rn,
         COUNT(*) OVER (PARTITION BY set_name, service_id) AS n
  FROM robust_draw_rank)
SELECT set_name, service_id,
  AVG(CASE WHEN rk <= 10 THEN 1.0 ELSE 0 END) AS top10_rate,
  AVG(CASE WHEN rk <= 25 THEN 1.0 ELSE 0 END) AS top25_rate,
  AVG(rk) AS mean_rank, MIN(rk) AS best_rank, MAX(rk) AS worst_rank,
  MAX(CASE WHEN rn = MAX(1, CAST(0.10*n AS INTEGER)) THEN rk END) AS p10_rank,
  MAX(CASE WHEN rn = MAX(1, CAST(0.50*n AS INTEGER)) THEN rk END) AS median_rank,
  MAX(CASE WHEN rn = MAX(1, CAST(0.90*n AS INTEGER)) THEN rk END) AS p90_rank
FROM ordered GROUP BY set_name, service_id;

CREATE VIEW v_robustness AS
SELECT r.set_name, r.service_id, s.service_name, s.stage2_priority, f.category,
       r.top10_rate, r.top25_rate, r.mean_rank, r.median_rank, r.p10_rank, r.p90_rank, r.best_rank, r.worst_rank,
       f.rank_balanced AS rank_balanced_workbook
FROM robustness r JOIN dim_service s ON s.service_id = r.service_id JOIN fact_score f ON f.service_id = r.service_id;

-- C. Break-even leakage: what share of loss-of-function patients must the lab route miss for whole-site POC
-- to cost no more than a given amount per extra stroke avoided (5 years, working mix)?
-- The willingness-to-pay grid is HYPOTHETICAL (dim_wtp), not a NICE threshold and not a sourced figure.
-- extra strokes avoided = leakage * strokes_avoided_5y_working (as in 08C column X).
CREATE VIEW v_breakeven AS
SELECT s.service_id, s.service_name, s.stage2_priority, f.category, w.wtp_id, w.gbp_per_stroke_avoided,
       c.poc_premium_over_lab, c.strokes_avoided_5y_working,
       c.poc_premium_over_lab / (w.gbp_per_stroke_avoided * c.strokes_avoided_5y_working) AS breakeven_leakage_raw,
       CASE WHEN c.poc_premium_over_lab / (w.gbp_per_stroke_avoided * c.strokes_avoided_5y_working) <= 1
            THEN c.poc_premium_over_lab / (w.gbp_per_stroke_avoided * c.strokes_avoided_5y_working) END AS breakeven_leakage
FROM dim_service s
JOIN fact_cost c ON c.service_id = s.service_id
JOIN fact_score f ON f.service_id = s.service_id
CROSS JOIN dim_wtp w
WHERE s.greenfield_flag = 1 AND c.strokes_avoided_5y_working > 0;

CREATE VIEW v_breakeven_national AS
SELECT w.wtp_id, w.gbp_per_stroke_avoided,
       SUM(c.poc_premium_over_lab) AS premium_gbp,
       SUM(c.strokes_avoided_5y_working) AS strokes_5y_if_all_lof_switched,
       SUM(c.poc_premium_over_lab) / (w.gbp_per_stroke_avoided * SUM(c.strokes_avoided_5y_working)) AS breakeven_leakage_raw
FROM fact_cost c JOIN dim_service s ON s.service_id = c.service_id AND s.greenfield_flag = 1
CROSS JOIN dim_wtp w WHERE c.strokes_avoided_5y_working > 0
GROUP BY w.wtp_id, w.gbp_per_stroke_avoided;

-- D. Leakage grid: extra strokes avoided and premium per extra stroke, by service and leakage level.
CREATE VIEW v_leakage_grid AS
SELECT s.service_id, s.service_name, g.leakage,
       g.leakage * c.strokes_avoided_5y_working AS extra_strokes_5y,
       c.poc_premium_over_lab AS premium_gbp,
       c.poc_premium_over_lab / (g.leakage * c.strokes_avoided_5y_working) AS premium_per_extra_stroke
FROM dim_service s JOIN fact_cost c ON c.service_id = s.service_id
CROSS JOIN (SELECT 0.05 AS leakage UNION ALL SELECT 0.10 UNION ALL SELECT 0.25 UNION ALL SELECT 0.50) g
WHERE s.greenfield_flag = 1 AND c.strokes_avoided_5y_working > 0;

-- E. Evidence-uplift opportunity: what is the revenue gap between the category-adjusted view and the flat view,
-- and which unassessed sites carry most of it? (Value of finding out.)
CREATE VIEW v_evidence_uplift AS
SELECT s.service_id, s.service_name, i.icb_short AS icb, f.category, f.timing_adj,
       f.revenue_flat25, f.revenue_category_adjusted, f.revenue_flat25 - f.revenue_category_adjusted AS revenue_at_stake
FROM dim_service s JOIN dim_icb i ON i.icb_id = s.icb_id JOIN fact_score f ON f.service_id = s.service_id
WHERE s.greenfield_flag = 1 AND f.category LIKE 'Evidence needed%';
