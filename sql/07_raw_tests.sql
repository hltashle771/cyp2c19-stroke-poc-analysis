-- Raw-layer reconciliation: the database built from the model workbook must agree with the user's master.
INSERT INTO test_results SELECT 'raw_master rows (98 in scope + 1 excluded)', 99, COUNT(*), 0, 0 FROM raw_master;
INSERT INTO test_results SELECT 'raw_master rows in scope', 98, COUNT(*), 0, 0 FROM raw_master WHERE analysis_scope='INCLUDE';
INSERT INTO test_results SELECT 'dim_service ids missing from master', 0, COUNT(*), 0, 0 FROM dim_service WHERE service_id NOT IN (SELECT service_id FROM raw_master);
INSERT INTO test_results SELECT 'in-scope master ids missing from dim_service', 0, COUNT(*), 0, 0 FROM raw_master WHERE analysis_scope='INCLUDE' AND service_id NOT IN (SELECT service_id FROM dim_service);
INSERT INTO test_results SELECT 'quarterly ischaemic: model vs master, max abs diff', 0, MAX(ABS(f.quarterly_ischaemic - m.est_quarterly_infarction_n)), 1e-6, 0
  FROM fact_service_metrics f JOIN v_master_clean m USING(service_id) WHERE f.quarterly_ischaemic IS NOT NULL AND m.est_quarterly_infarction_n IS NOT NULL;
INSERT INTO test_results SELECT 'services where model has demand but master does not (or vice versa)', 0, COUNT(*), 0, 0
  FROM fact_service_metrics f JOIN v_master_clean m USING(service_id) WHERE (f.quarterly_ischaemic IS NULL) <> (m.est_quarterly_infarction_n IS NULL);
INSERT INTO test_results SELECT 'median stay: model vs master, max abs diff', 0, MAX(ABS(f.median_stay_days - m.median_su_los_days)), 1e-6, 0
  FROM fact_service_metrics f JOIN v_master_clean m USING(service_id) WHERE f.median_stay_days IS NOT NULL AND m.median_su_los_days IS NOT NULL;
INSERT INTO test_results SELECT 'TIA wait: model vs master, max abs diff', 0, MAX(ABS(f.tia_wait_days - m.tia_referral_wait_days)), 1e-6, 0
  FROM fact_service_metrics f JOIN v_master_clean m USING(service_id) WHERE f.tia_wait_days IS NOT NULL AND m.tia_referral_wait_days IS NOT NULL;
INSERT INTO test_results SELECT 'thrombectomy flag mismatches model vs master', 0, COUNT(*), 0, 0
  FROM dim_service s JOIN v_master_clean m USING(service_id) WHERE s.thrombectomy_flag <> m.thrombectomy_flag;
INSERT INTO test_results SELECT 'Stage 2 lab text names a different GLH than the master (Leicester only: known open fix)', 1, COUNT(*), 0, 0 FROM v_glh_conflicts;
INSERT INTO test_results SELECT 'raw_glh_region rows (7 GLHs)', 7, COUNT(*), 0, 0 FROM raw_glh_region;
INSERT INTO test_results SELECT 'every dim_service GLH exists in raw_glh_region', 0, COUNT(*), 0, 0 FROM dim_service WHERE glh_region NOT IN (SELECT glh_region FROM raw_glh_region);
INSERT INTO test_results SELECT 'distinct ICBs in raw_icb_lookup', 36, COUNT(DISTINCT current_icb_code_2026), 0, 0 FROM raw_icb_lookup;
INSERT INTO test_results SELECT 'stage2 rows', 25, COUNT(*), 0, 0 FROM raw_stage2;
INSERT INTO test_results SELECT 'stage2 priority: model vs raw stage2 mismatches', 0, COUNT(*), 0, 0
  FROM raw_stage2 r JOIN dim_service s USING(service_id) WHERE COALESCE(s.stage2_timing_evidence,'') <> COALESCE(r.timing_gap_evidence,'');
INSERT INTO test_results SELECT 'raw_crosswalk rows', 99, COUNT(*), 0, 0 FROM raw_crosswalk;
UPDATE test_results SET pass = CASE WHEN ABS(expected - actual) <= MAX(tolerance, 0) AND (tolerance > 0 OR expected = actual OR ABS(expected-actual) < 1e-9) THEN 1 ELSE 0 END;
