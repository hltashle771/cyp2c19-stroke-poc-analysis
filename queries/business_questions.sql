-- Ten business questions answered from the database. Each statement is runnable on its own.

-- Q1. Top 10 greenfield sites under the Balanced lens, with category and timing evidence.
SELECT rank_balanced AS rank, service_name, icb, category, timing_adj, ROUND(score_balanced,1) AS score
FROM v_service_full WHERE rank_balanced <= 10 ORDER BY rank_balanced;

-- Q2. Which sites stay in the top 25 in at least 95% of 2,000 random weightings? (the robust core)
SELECT service_id, service_name, ROUND(top25_rate,2) AS top25_rate, median_rank, p10_rank, p90_rank
FROM v_robustness WHERE set_name = 'free' AND top25_rate >= 0.95 ORDER BY median_rank;

-- Q3. Among sites with a median rank in the top 40, which depend most on the weighting? (widest p10 to p90 range)
SELECT service_id, service_name, p10_rank, median_rank, p90_rank, p90_rank - p10_rank AS rank_range
FROM v_robustness WHERE set_name = 'free' AND median_rank <= 40 ORDER BY rank_range DESC LIMIT 10;

-- Q4. Where does the Priority A set sit, and how robust is each site?
SELECT s.service_id, s.service_name, f.rank_balanced, f.rank_volume, f.rank_fit, ROUND(r.top10_rate,2) AS top10_rate, f.category
FROM dim_service s JOIN fact_score f USING(service_id) JOIN robustness r ON r.service_id = s.service_id AND r.set_name = 'free'
WHERE s.stage2_priority = 'A' ORDER BY f.rank_balanced;

-- Q5. Which ICBs hold the most revenue but the least evidence?
SELECT icb, services, ROUND(revenue_category_adjusted) AS revenue, with_timing_evidence, evidence_needed
FROM v_icb_rollup ORDER BY revenue_category_adjusted DESC LIMIT 10;

-- Q6. How much leakage would the lab route need for whole-site POC to break even at each hypothetical value per stroke avoided?
SELECT gbp_per_stroke_avoided AS gbp_per_extra_stroke, ROUND(breakeven_leakage_raw,3) AS leakage_needed
FROM v_breakeven_national ORDER BY gbp_per_stroke_avoided;

-- Q7. Where would finding out the route be worth most? (evidence-needed sites by revenue at stake)
SELECT service_id, service_name, icb, ROUND(revenue_at_stake) AS revenue_at_stake FROM v_evidence_uplift ORDER BY revenue_at_stake DESC LIMIT 10;

-- Q8. Hybrid and POC-led candidates with their premium per loss-of-function patient found.
SELECT service_name, category, ROUND(tests_central) AS tests, ROUND(poc_premium_over_lab) AS premium_if_all_poc, ROUND(premium_per_lof,1) AS premium_per_lof
FROM v_service_full WHERE category IN ('POC-led candidate','Hybrid candidate') ORDER BY rank_balanced;

-- Q9. Does the thrombectomy-centre share change when POC fit is weighted more? (scope hypothesis proxy)
SELECT thrombectomy_flag, services, in_top25_balanced, in_top25_fit, ROUND(revenue_category_adjusted) AS revenue FROM v_thrombectomy_split;

-- Q10. Services with missing metrics (neutral-scored, listed so nobody mistakes them for low performers).
SELECT s.service_id, s.service_name, m.median_stay_days IS NULL AS missing_stay, m.tia_wait_days IS NULL AS missing_tia_wait, m.annual_ischaemic IS NULL AS missing_demand
FROM dim_service s JOIN fact_service_metrics m USING(service_id)
WHERE m.median_stay_days IS NULL OR m.tia_wait_days IS NULL OR m.annual_ischaemic IS NULL;

-- Q11. Fields the Excel model never used: what do the top-10 greenfield services look like on beds, TIA clinic access and 72h care?
SELECT rank_balanced, service_name, category, est_quarterly_infarction_n AS quarterly_infarcts, stroke_unit_beds_total AS su_beds,
       tia_clinic_flag, tia_clinic_days_week, tia_inpatient_timescale, first72h_care_onsite
FROM v_service_master WHERE rank_balanced <= 10 ORDER BY rank_balanced;

-- Q12. Which services have no TIA clinic, or one that sits only part of the week? (TIA pathway = the POC use case)
SELECT service_id, service_name, tia_clinic_flag, tia_clinic_days_week, tia_referral_wait_days
FROM v_service_master WHERE tia_clinic_flag = 0 OR tia_clinic_days_week < 5 ORDER BY tia_clinic_days_week;

-- Q13. Data-quality audit: master rows with SSNAP-suppressed values, and Stage 2 vs master disagreements.
SELECT service_id, team_name, case_ascertainment_72h, suppressed_flag FROM v_master_clean WHERE suppressed_flag = 1;
SELECT * FROM v_glh_conflicts;

-- Q14. v1 (workbook) vs v2 (extended): who moves most under the Balanced lens? Positive = rises under v2.
SELECT service_name, stage2_priority, rank_v1, rank_v2, places_gained, timescale_score, clinic_days_score
FROM v_v1_v2_rank WHERE lens_name = 'Balanced' ORDER BY ABS(places_gained) DESC LIMIT 15;

-- Q15. How sensitive is the answer to the judgement weights? (top-10 and top-25 kept, Priority A in the top 25)
SELECT * FROM v_variant_sensitivity;

-- Q16. Does the robust core change? Sites whose top-25 rate crosses the 95% line between v1 and v2 (free weights).
SELECT service_name, stage2_priority, ROUND(top25_v1,3) AS top25_v1, ROUND(top25_v2,3) AS top25_v2
FROM v_robust_v1_v2 WHERE set_name = 'free' AND (top25_v1 >= 0.95) <> (top25_v2 >= 0.95);
