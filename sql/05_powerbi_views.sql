-- Convenience views for Power BI (and anyone else who wants flat tables).
CREATE VIEW v_fact_score_pbi AS
SELECT f.*, cen.tests AS tests_central, cen.tests * f.poc_share AS poc_tests_category,
       CASE f.category WHEN 'POC-led candidate' THEN 1 WHEN 'Hybrid candidate' THEN 2
            WHEN 'Evidence needed (research priority)' THEN 3 WHEN 'Evidence needed (lower priority)' THEN 4
            WHEN 'Lab-led (timing)' THEN 5 ELSE 6 END AS category_sort
FROM fact_score f
LEFT JOIN fact_scenario cen ON cen.service_id = f.service_id AND cen.scenario = 'Central';

CREATE VIEW v_calibration_pbi AS
SELECT block, label, value, n, ci_low, ci_high FROM fact_calibration;
