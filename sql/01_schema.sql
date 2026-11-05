-- Genedrive CYP2C19 portfolio: relational schema (SQLite; ANSI-style, ports to PostgreSQL / SQL Server)
-- Star-ish model: dim_service is the hub; facts hang off service_id. Scenario data is long format.
PRAGMA foreign_keys = ON;

CREATE TABLE dim_icb (
  icb_id INTEGER PRIMARY KEY,
  icb_name TEXT NOT NULL UNIQUE,
  icb_short TEXT NOT NULL
);
CREATE TABLE dim_service (
  service_id TEXT PRIMARY KEY,
  service_name TEXT NOT NULL,
  trust TEXT NOT NULL,
  icb_id INTEGER NOT NULL REFERENCES dim_icb(icb_id),
  glh_region TEXT NOT NULL,
  stage2_priority TEXT,
  genedrive_status TEXT,
  competitive_position TEXT,
  thrombectomy_flag INTEGER NOT NULL CHECK (thrombectomy_flag IN (0,1)),
  greenfield_flag INTEGER NOT NULL CHECK (greenfield_flag IN (0,1)),
  incumbent_flag INTEGER NOT NULL CHECK (incumbent_flag IN (0,1)),
  stage2_timing_evidence TEXT,
  stage2_readiness TEXT,
  commercial_archetype TEXT,
  critical_next_question TEXT,
  CHECK (greenfield_flag + incumbent_flag = 1)
);
CREATE TABLE fact_service_metrics (
  service_id TEXT PRIMARY KEY REFERENCES dim_service(service_id),
  quarterly_ischaemic REAL, annual_ischaemic REAL, nonminor_strokes REAL, minor_strokes REAL, tia_proxy REAL,
  median_stay_days REAL, tia_wait_days REAL, tia_final_diagnoses REAL
);
CREATE TABLE dim_scenario (
  scenario TEXT PRIMARY KEY CHECK (scenario IN ('Limited','Central','Higher')),
  sort_order INTEGER NOT NULL
);
CREATE TABLE fact_scenario (
  service_id TEXT NOT NULL REFERENCES dim_service(service_id),
  scenario TEXT NOT NULL REFERENCES dim_scenario(scenario),
  tests REAL, lof_patients_found REAL, poc_tests_flat25 REAL,
  kit_revenue REAL, fixed_revenue REAL, total_revenue REAL,
  PRIMARY KEY (service_id, scenario)
);
CREATE TABLE fact_cost (
  service_id TEXT PRIMARY KEY REFERENCES dim_service(service_id),
  tests_central REAL, lab_test_cash REAL, lab_staff REAL, poc_test_cash REAL, poc_staff REAL,
  hybrid_test_cash REAL, hybrid_staff REAL, poc_premium_over_lab REAL, lof_patients REAL, premium_per_lof REAL,
  drug_cost_all_ticagrelor REAL, drug_cost_all_dipasp REAL, drug_cost_working_mix REAL,
  strokes_avoided_5y_ticagrelor REAL, strokes_avoided_5y_dipasp REAL, strokes_avoided_5y_working REAL,
  strokes_avoided_90d_ticagrelor REAL, strokes_avoided_90d_dipasp REAL, strokes_avoided_90d_working REAL,
  incremental_cash_vs_no_testing REAL, cash_per_stroke_avoided_5y REAL,
  extra_strokes_avoided_if_poc_recovers_leakage REAL, poc_premium_per_extra_stroke REAL
);
CREATE TABLE fact_score (
  service_id TEXT PRIMARY KEY REFERENCES dim_service(service_id),
  timing_adj TEXT, readiness_adj TEXT,
  demand_score REAL, stay_score REAL, tia_speed_score REAL, time_sensitivity_score REAL,
  poc_suitability_score REAL, readiness_score REAL, data_gaps REAL,
  score_balanced REAL, score_volume REAL, score_fit REAL,
  rank_balanced INTEGER, rank_volume INTEGER, rank_fit INTEGER,
  best_rank INTEGER, worst_rank INTEGER, rank_spread INTEGER,
  in_top_n INTEGER, on_shortlist INTEGER,
  category TEXT, poc_share REAL,
  revenue_category_adjusted REAL, revenue_flat25 REAL, revenue_change REAL
);
CREATE TABLE dim_lens (
  lens_id INTEGER PRIMARY KEY, lens_name TEXT NOT NULL UNIQUE,
  w_demand REAL NOT NULL, w_time_sensitivity REAL NOT NULL, w_poc_suitability REAL NOT NULL, w_readiness REAL NOT NULL,
  CHECK (ABS(w_demand + w_time_sensitivity + w_poc_suitability + w_readiness - 1) < 1e-9)
);
CREATE TABLE fact_override (
  service_id TEXT NOT NULL REFERENCES dim_service(service_id),
  timing_override TEXT, readiness_override TEXT, reason TEXT, evidence_id TEXT
);
CREATE TABLE dim_parameter (
  param_id INTEGER PRIMARY KEY, parameter TEXT, unit TEXT, limited REAL, central REAL, higher REAL,
  source_type TEXT, source_reference TEXT, status TEXT
);
CREATE TABLE dim_assumption (
  assumption_id INTEGER PRIMARY KEY, "where" TEXT, assumption TEXT, status TEXT, impact TEXT, what_would_change_it TEXT
);
CREATE TABLE dim_source (
  source_id TEXT PRIMARY KEY, type TEXT, title TEXT, publisher TEXT, url_or_file TEXT, date TEXT,
  reliability TEXT, used_for TEXT, caveat TEXT
);
CREATE TABLE fact_evidence (
  evidence_id TEXT PRIMARY KEY, finding TEXT, source TEXT, reliability TEXT, used_for TEXT
);
CREATE TABLE fact_calibration (
  block TEXT, label TEXT, value REAL, n REAL, ci_low REAL, ci_high REAL
);
CREATE TABLE shortlist_notes (
  service_id TEXT PRIMARY KEY, evidence_basis TEXT, main_caveat TEXT, next_step TEXT
);
CREATE TABLE workbook_checks (check_name TEXT PRIMARY KEY, expected REAL);
-- Analysis support tables (populated by build_db.py)
CREATE TABLE weight_draw (
  set_name TEXT NOT NULL, draw_id INTEGER NOT NULL,
  w_demand REAL, w_time_sensitivity REAL, w_poc_suitability REAL, w_readiness REAL,
  PRIMARY KEY (set_name, draw_id)
);
CREATE TABLE dim_wtp (
  wtp_id INTEGER PRIMARY KEY, label TEXT, gbp_per_stroke_avoided REAL
);
CREATE INDEX ix_service_icb ON dim_service(icb_id);
CREATE INDEX ix_score_category ON fact_score(category);
