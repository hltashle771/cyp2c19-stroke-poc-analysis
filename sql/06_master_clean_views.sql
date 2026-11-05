-- Typed, cleaned views over the raw master. Rule: a value is numeric only if it looks like a number;
-- SSNAP suppression codes ('Too few to report', 'Case ascertainment < 60%', '.') become NULL, and
-- suppressed_flag records that it happened. (SQLite CAST('text' AS REAL) silently gives 0.0, so we GLOB-guard.)
CREATE VIEW v_master_clean AS
SELECT
  service_id, team_name, trust_name, ssnap_region, crosswalk_match_status, clinical_period, oa_snapshot,
  case_ascertainment_72h,
  CASE WHEN patient_centred_stroke_n GLOB '[0-9]*' AND patient_centred_stroke_n NOT GLOB '*[^0-9.]*' THEN CAST(patient_centred_stroke_n AS REAL) END AS patient_centred_stroke_n,
  CASE WHEN team_centred_stroke_n GLOB '[0-9]*' AND team_centred_stroke_n NOT GLOB '*[^0-9.]*' THEN CAST(team_centred_stroke_n AS REAL) END AS team_centred_stroke_n,
  CASE WHEN infarction_n_patient_centred GLOB '[0-9]*' AND infarction_n_patient_centred NOT GLOB '*[^0-9.]*' THEN CAST(infarction_n_patient_centred AS REAL) END AS infarction_n_patient_centred,
  CASE WHEN infarction_pct GLOB '[0-9]*' AND infarction_pct NOT GLOB '*[^0-9.]*' THEN CAST(infarction_pct AS REAL) END AS infarction_pct,
  CASE WHEN estimated_team_centred_infarction_n GLOB '[0-9]*' AND estimated_team_centred_infarction_n NOT GLOB '*[^0-9.]*' THEN CAST(estimated_team_centred_infarction_n AS REAL) END AS est_quarterly_infarction_n,
  CASE WHEN median_total_los_days GLOB '[0-9]*' AND median_total_los_days NOT GLOB '*[^0-9.]*' THEN CAST(median_total_los_days AS REAL) END AS median_total_los_days,
  CASE WHEN median_stroke_unit_los_days GLOB '[0-9]*' AND median_stroke_unit_los_days NOT GLOB '*[^0-9.]*' THEN CAST(median_stroke_unit_los_days AS REAL) END AS median_su_los_days,
  CASE WHEN stroke_unit_beds_total GLOB '[0-9]*' AND stroke_unit_beds_total NOT GLOB '*[^0-9.]*' THEN CAST(stroke_unit_beds_total AS REAL) END AS stroke_unit_beds_total,
  CASE WHEN type1_beds_72h GLOB '[0-9]*' AND type1_beds_72h NOT GLOB '*[^0-9.]*' THEN CAST(type1_beds_72h AS REAL) END AS type1_beds_72h,
  CASE WHEN type3_beds_mixed GLOB '[0-9]*' AND type3_beds_mixed NOT GLOB '*[^0-9.]*' THEN CAST(type3_beds_mixed AS REAL) END AS type3_beds_mixed,
  CASE WHEN acute_capable_beds GLOB '[0-9]*' AND acute_capable_beds NOT GLOB '*[^0-9.]*' THEN CAST(acute_capable_beds AS REAL) END AS acute_capable_beds,
  first72h_care_onsite,
  CASE thrombectomy_centre WHEN 'YES' THEN 1 WHEN 'NO' THEN 0 END AS thrombectomy_flag,
  CASE tia_clinic_present WHEN 'YES' THEN 1 WHEN 'NO' THEN 0 END AS tia_clinic_flag,
  CASE WHEN tia_clinic_days_week GLOB '[0-9]*' AND tia_clinic_days_week NOT GLOB '*[^0-9.]*' THEN CAST(tia_clinic_days_week AS REAL) END AS tia_clinic_days_week,
  CASE WHEN tia_final_diagnosis_n GLOB '[0-9]*' AND tia_final_diagnosis_n NOT GLOB '*[^0-9.]*' THEN CAST(tia_final_diagnosis_n AS REAL) END AS tia_final_diagnosis_n,
  CASE WHEN tia_referral_wait_days GLOB '[0-9]*' AND tia_referral_wait_days NOT GLOB '*[^0-9.]*' THEN CAST(tia_referral_wait_days AS REAL) END AS tia_referral_wait_days,
  NULLIF(tia_inpatient_timescale,'.') AS tia_inpatient_timescale,
  NULLIF(tia_outpatient_timescale,'.') AS tia_outpatient_timescale,
  site_ods_code, ods_site_name, site_postcode, trust_ods_code, current_ods_trust_name,
  current_icb_code_2026, current_icb_name_2026, nhse_region_code, glh_region, ods_match_status, glh_status, analysis_scope,
  CASE WHEN patient_centred_stroke_n GLOB '*[^0-9.]*' OR median_total_los_days GLOB '*[^0-9.]*'
         OR tia_referral_wait_days = '.' THEN 1 ELSE 0 END AS suppressed_flag
FROM raw_master;

-- Master joined to the model: one row per modelled service, raw fields beside model outputs.
-- Includes master fields the model does not yet use (bed counts, TIA clinic access, ODS site, 72h care).
CREATE VIEW v_service_master AS
SELECT s.service_id, s.service_name, s.glh_region AS model_glh, m.glh_region AS master_glh,
       s.stage2_priority, s.genedrive_status, f.category, f.rank_balanced, f.rank_volume, f.rank_fit, f.revenue_category_adjusted,
       m.est_quarterly_infarction_n, m.median_su_los_days, m.stroke_unit_beds_total, m.type1_beds_72h, m.acute_capable_beds,
       m.tia_clinic_flag, m.tia_clinic_days_week, m.tia_referral_wait_days, m.tia_inpatient_timescale, m.tia_outpatient_timescale,
       m.first72h_care_onsite, m.case_ascertainment_72h, m.site_ods_code, m.trust_ods_code, m.current_icb_name_2026
FROM dim_service s
JOIN v_master_clean m USING(service_id)
LEFT JOIN fact_score f USING(service_id);

-- Stage 2 synthesis (25 services) typed: the commercial-intel fields behind readiness and timing evidence.
CREATE VIEW v_stage2_clean AS
SELECT service_id, team_name, stage1_cohort, cyp2c19_testing_status, testing_route,
       NULLIF(laboratory_provider,'') AS laboratory_provider, NULLIF(published_turnaround,'') AS published_turnaround,
       evidence_confidence, timing_gap_evidence, implementation_readiness, competitive_position,
       commercial_archetype, investigation_priority, critical_next_question, primary_source_url
FROM raw_stage2;

-- GLH: region reference plus trust->GLH mapping, with services per region.
CREATE VIEW v_glh_reference AS
SELECT g.glh_region, g.clinical_genomics_services,
       (SELECT COUNT(*) FROM raw_glh_trust t WHERE t.glh_region = g.glh_region) AS trusts_mapped,
       (SELECT COUNT(*) FROM dim_service s WHERE s.glh_region = g.glh_region) AS modelled_services
FROM raw_glh_region g;

-- Stage 2 lab-provider text that names a GLH different from the master's GLH for that service.
-- Expected: Leicester only (Stage 2 cites a North West GLH evaluation; the master maps the trust to East). Known open fix.
CREATE VIEW v_glh_conflicts AS
SELECT s.service_id, s.team_name, m.glh_region AS master_glh, g.glh_region AS glh_named_in_stage2, s.laboratory_provider
FROM raw_stage2 s
JOIN raw_master m USING(service_id)
JOIN raw_glh_region g ON s.laboratory_provider LIKE g.glh_region || ' Genomic%' AND g.glh_region <> m.glh_region;
