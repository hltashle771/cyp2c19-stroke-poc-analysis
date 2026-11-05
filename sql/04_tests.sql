-- Reconciliation tests: SQL results must equal the workbook. Table test_results; every row must pass.
CREATE TABLE test_results (test_name TEXT, expected REAL, actual REAL, tolerance REAL, pass INTEGER);
INSERT INTO test_results SELECT 'dim_service rows', 98, COUNT(*), 0, 0 FROM dim_service;
INSERT INTO test_results SELECT 'dim_icb rows', 36, COUNT(*), 0, 0 FROM dim_icb;
INSERT INTO test_results SELECT 'fact_scenario rows (98 x 3)', 294, COUNT(*), 0, 0 FROM fact_scenario;
INSERT INTO test_results SELECT 'incumbent services', 3, SUM(incumbent_flag), 0, 0 FROM dim_service;
INSERT INTO test_results SELECT 'incumbents with a non-incumbent category', 0, COUNT(*), 0, 0
  FROM dim_service s JOIN fact_score f USING(service_id) WHERE s.incumbent_flag = 1 AND f.category <> 'Incumbent / reference';
INSERT INTO test_results SELECT 'tests (Central) total vs workbook', (SELECT expected FROM workbook_checks WHERE check_name='tests_central_total'), SUM(tests), 1e-6, 0 FROM fact_scenario WHERE scenario='Central';
INSERT INTO test_results SELECT 'greenfield flat-25% revenue vs workbook', (SELECT expected FROM workbook_checks WHERE check_name='greenfield_flat25_revenue_total'), SUM(revenue_flat25), 1e-6, 0 FROM fact_score;
INSERT INTO test_results SELECT 'category-adjusted revenue vs workbook', (SELECT expected FROM workbook_checks WHERE check_name='category_adjusted_revenue_total'), SUM(revenue_category_adjusted), 1e-6, 0 FROM fact_score;
INSERT INTO test_results SELECT 'ICB view revenue total = workbook', (SELECT expected FROM workbook_checks WHERE check_name='category_adjusted_revenue_total'), SUM(revenue_category_adjusted), 1e-6, 0 FROM v_icb_rollup;
INSERT INTO test_results SELECT 'ICB view services total', 98, SUM(services), 0, 0 FROM v_icb_rollup;
INSERT INTO test_results SELECT 'research shortlist count vs workbook', (SELECT expected FROM workbook_checks WHERE check_name='research_shortlist_count'), SUM(on_shortlist), 0, 0 FROM fact_score;
INSERT INTO test_results SELECT 'top 25 under all three lenses vs workbook', (SELECT expected FROM workbook_checks WHERE check_name='top25_all_three_lenses'), COUNT(*), 0, 0 FROM fact_score WHERE rank_balanced<=25 AND rank_volume<=25 AND rank_fit<=25;
INSERT INTO test_results SELECT 'largest rank spread vs workbook', (SELECT expected FROM workbook_checks WHERE check_name='largest_rank_spread'), MAX(rank_spread), 0, 0 FROM fact_score;
INSERT INTO test_results SELECT 'recomputed '||l.lens_name||' score: max abs diff vs workbook', 0,
  MAX(ABS(r.score - CASE l.lens_id WHEN 1 THEN f.score_balanced WHEN 2 THEN f.score_volume ELSE f.score_fit END)), 1e-6, 0
  FROM score_recompute r JOIN dim_lens l USING(lens_id) JOIN fact_score f USING(service_id) GROUP BY l.lens_id, l.lens_name;
INSERT INTO test_results SELECT 'recomputed '||l.lens_name||' rank: mismatches vs workbook', 0,
  SUM(CASE WHEN r.rank_recomputed <> CASE l.lens_id WHEN 1 THEN f.rank_balanced WHEN 2 THEN f.rank_volume ELSE f.rank_fit END THEN 1 ELSE 0 END), 0, 0
  FROM score_recompute r JOIN dim_lens l USING(lens_id) JOIN fact_score f USING(service_id) GROUP BY l.lens_id, l.lens_name;
INSERT INTO test_results SELECT 'weight draws', 4000, COUNT(*), 0, 0 FROM weight_draw;
INSERT INTO test_results SELECT 'weight draws sum to 1 (max deviation)', 0, MAX(ABS(w_demand+w_time_sensitivity+w_poc_suitability+w_readiness-1)), 1e-9, 0 FROM weight_draw;
INSERT INTO test_results SELECT 'robustness rows (2 sets x ranked greenfield)', 2*(SELECT COUNT(*) FROM score_recompute WHERE lens_id=1), COUNT(*), 0, 0 FROM robustness;
INSERT INTO test_results SELECT 'extra strokes = leakage(Central) x strokes avoided: max abs diff', 0,
  MAX(ABS(c.extra_strokes_avoided_if_poc_recovers_leakage - (SELECT central FROM dim_parameter WHERE param_id=25) * c.strokes_avoided_5y_working)), 1e-6, 0
  FROM fact_cost c WHERE c.extra_strokes_avoided_if_poc_recovers_leakage IS NOT NULL;
INSERT INTO test_results SELECT 'break-even at hypothetical £50k: leakage x strokes x £50k = premium (max abs diff)', 0,
  MAX(ABS(breakeven_leakage_raw * 50000 * strokes_avoided_5y_working - poc_premium_over_lab)), 1e-6, 0
  FROM v_breakeven WHERE gbp_per_stroke_avoided = 50000;
UPDATE test_results SET pass = CASE WHEN ABS(expected - actual) <= MAX(tolerance, 0) AND (tolerance > 0 OR expected = actual OR ABS(expected-actual) < 1e-9) THEN 1 ELSE 0 END;
