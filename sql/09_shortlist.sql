-- Shortlist: one row per POC-led or Hybrid candidate, with the scores that placed it and the evidence behind it.
-- Scores and ranks come from fact_score; robustness from the 'free' weight set; text from shortlist_notes.
CREATE VIEW v_shortlist AS
SELECT s.service_id, s.service_name, f.category,
       f.rank_balanced, f.rank_volume, f.rank_fit,
       ROUND(f.demand_score,1) AS demand_score, ROUND(f.time_sensitivity_score,1) AS time_sensitivity_score,
       ROUND(f.poc_suitability_score,1) AS poc_suitability_score, ROUND(f.readiness_score,1) AS readiness_score,
       ROUND(c.tests,0) AS tests_central, f.timing_adj, f.readiness_adj,
       ROUND(r.top10_rate,3) AS top10_rate, ROUND(f.revenue_category_adjusted,0) AS revenue_category_adjusted,
       n.evidence_basis, n.main_caveat, n.next_step
FROM fact_score f
JOIN dim_service s USING(service_id)
LEFT JOIN fact_scenario c ON c.service_id=f.service_id AND c.scenario='Central'
LEFT JOIN v_robustness r ON r.service_id=f.service_id AND r.set_name='free'
LEFT JOIN shortlist_notes n ON n.service_id=f.service_id
WHERE f.category IN ('POC-led candidate','Hybrid candidate');

INSERT INTO test_results SELECT 'shortlist rows = candidate categories', (SELECT COUNT(*) FROM fact_score WHERE category IN ('POC-led candidate','Hybrid candidate')), COUNT(*), 0, 0 FROM v_shortlist;
INSERT INTO test_results SELECT 'shortlist rows without an evidence note', 0, COUNT(*), 0, 0 FROM v_shortlist WHERE evidence_basis IS NULL;
UPDATE test_results SET pass = CASE WHEN ABS(expected - actual) <= MAX(tolerance, 0) AND (tolerance > 0 OR expected = actual OR ABS(expected-actual) < 1e-9) THEN 1 ELSE 0 END;
