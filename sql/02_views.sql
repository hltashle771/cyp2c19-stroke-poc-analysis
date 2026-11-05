-- Reporting views. Power BI can read these or the underlying tables.
CREATE VIEW v_service_full AS
SELECT s.service_id, s.service_name, s.trust, i.icb_short AS icb, s.icb_id, s.glh_region, s.stage2_priority,
       s.genedrive_status, s.competitive_position, s.thrombectomy_flag, s.greenfield_flag,
       m.annual_ischaemic, m.median_stay_days, m.tia_wait_days,
       lim.tests AS tests_limited, cen.tests AS tests_central, hi.tests AS tests_higher,
       cen.lof_patients_found AS lof_patients_central,
       f.timing_adj, f.readiness_adj, f.category, f.poc_share,
       f.score_balanced, f.score_volume, f.score_fit, f.rank_balanced, f.rank_volume, f.rank_fit, f.rank_spread, f.on_shortlist,
       f.revenue_category_adjusted, f.revenue_flat25,
       c.poc_premium_over_lab, c.premium_per_lof, c.extra_strokes_avoided_if_poc_recovers_leakage, c.poc_premium_per_extra_stroke
FROM dim_service s
JOIN dim_icb i ON i.icb_id = s.icb_id
LEFT JOIN fact_service_metrics m ON m.service_id = s.service_id
LEFT JOIN fact_scenario lim ON lim.service_id = s.service_id AND lim.scenario = 'Limited'
LEFT JOIN fact_scenario cen ON cen.service_id = s.service_id AND cen.scenario = 'Central'
LEFT JOIN fact_scenario hi  ON hi.service_id  = s.service_id AND hi.scenario  = 'Higher'
LEFT JOIN fact_score f ON f.service_id = s.service_id
LEFT JOIN fact_cost c ON c.service_id = s.service_id;

CREATE VIEW v_icb_rollup AS
SELECT i.icb_id, i.icb_short AS icb,
  COUNT(*) AS services, SUM(s.greenfield_flag) AS greenfield_services,
  SUM(m.annual_ischaemic) AS annual_ischaemic, SUM(cen.tests) AS tests_central,
  SUM(f.revenue_category_adjusted) AS revenue_category_adjusted, SUM(f.revenue_flat25) AS revenue_flat25,
  SUM(CASE WHEN f.category IN ('POC-led candidate','Hybrid candidate') THEN 1 ELSE 0 END) AS poc_led_or_hybrid,
  SUM(CASE WHEN f.category = 'Lab-led (timing)' THEN 1 ELSE 0 END) AS lab_led,
  SUM(CASE WHEN f.category LIKE 'Evidence needed%' THEN 1 ELSE 0 END) AS evidence_needed,
  SUM(CASE WHEN f.category = 'Incumbent / reference' THEN 1 ELSE 0 END) AS incumbent,
  SUM(COALESCE(f.on_shortlist,0)) AS on_shortlist,
  SUM(CASE WHEN f.timing_adj <> 'Unknown' THEN 1 ELSE 0 END) AS with_timing_evidence,
  MIN(f.rank_balanced) AS best_rank_balanced
FROM dim_icb i
JOIN dim_service s ON s.icb_id = i.icb_id
LEFT JOIN fact_service_metrics m ON m.service_id = s.service_id
LEFT JOIN fact_scenario cen ON cen.service_id = s.service_id AND cen.scenario = 'Central'
LEFT JOIN fact_score f ON f.service_id = s.service_id
GROUP BY i.icb_id, i.icb_short;

CREATE VIEW v_glh_rollup AS
SELECT s.glh_region, COUNT(*) AS services, SUM(s.greenfield_flag) AS greenfield_services,
  SUM(cen.tests) AS tests_central, SUM(f.revenue_category_adjusted) AS revenue_category_adjusted,
  SUM(f.revenue_flat25) AS revenue_flat25,
  SUM(CASE WHEN f.category IN ('POC-led candidate','Hybrid candidate') THEN 1 ELSE 0 END) AS poc_led_or_hybrid,
  SUM(CASE WHEN f.timing_adj <> 'Unknown' THEN 1 ELSE 0 END) AS with_timing_evidence
FROM dim_service s
LEFT JOIN fact_scenario cen ON cen.service_id = s.service_id AND cen.scenario = 'Central'
LEFT JOIN fact_score f ON f.service_id = s.service_id
GROUP BY s.glh_region;

CREATE VIEW v_category_summary AS
SELECT f.category, COUNT(*) AS services, SUM(cen.tests) AS tests_central,
  SUM(f.revenue_flat25) AS revenue_flat25, SUM(f.revenue_category_adjusted) AS revenue_category_adjusted,
  AVG(f.score_balanced) AS avg_score_balanced
FROM fact_score f
LEFT JOIN fact_scenario cen ON cen.service_id = f.service_id AND cen.scenario = 'Central'
GROUP BY f.category;

CREATE VIEW v_priority_tier AS
SELECT s.stage2_priority, COUNT(*) AS services, SUM(cen.tests) AS tests_central,
  SUM(f.revenue_category_adjusted) AS revenue_category_adjusted,
  AVG(f.rank_balanced) AS avg_rank_balanced
FROM dim_service s
LEFT JOIN fact_scenario cen ON cen.service_id = s.service_id AND cen.scenario = 'Central'
LEFT JOIN fact_score f ON f.service_id = s.service_id
GROUP BY s.stage2_priority;

CREATE VIEW v_thrombectomy_split AS
SELECT s.thrombectomy_flag, COUNT(*) AS services, SUM(f.revenue_category_adjusted) AS revenue_category_adjusted,
  SUM(CASE WHEN f.rank_balanced <= 25 THEN 1 ELSE 0 END) AS in_top25_balanced,
  SUM(CASE WHEN f.rank_fit <= 25 THEN 1 ELSE 0 END) AS in_top25_fit
FROM dim_service s JOIN fact_score f ON f.service_id = s.service_id
GROUP BY s.thrombectomy_flag;
