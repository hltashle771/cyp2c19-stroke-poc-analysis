"""Write the tables and views Power BI loads into powerbi/data/*.csv (run after build_db.py)."""
import sqlite3, csv, os
con=sqlite3.connect('genedrive.db'); os.makedirs('powerbi/data',exist_ok=True)
items={'dim_icb':'select * from dim_icb','dim_service':'select * from dim_service','dim_scenario':'select * from dim_scenario','dim_lens':'select * from dim_lens',
'fact_service_metrics':'select * from fact_service_metrics','fact_scenario':'select * from fact_scenario','fact_cost':'select * from fact_cost',
'fact_score':'select * from v_fact_score_pbi','fact_robustness':'select * from v_robustness','fact_breakeven_national':'select * from v_breakeven_national',
'fact_leakage_grid':'select * from v_leakage_grid','fact_evidence_uplift':'select * from v_evidence_uplift','fact_calibration':'select * from v_calibration_pbi',
'dim_assumption':'select * from dim_assumption','dim_source':'select * from dim_source','fact_evidence':'select * from fact_evidence','fact_override':'select * from fact_override',
'fact_rank_v2':"select service_id, lens_name, rank_v1, rank_v2, places_gained, timescale_score, clinic_days_score from v_v1_v2_rank",
'fact_variant_sensitivity':'select * from v_variant_sensitivity',
'fact_robust_v1_v2':'select set_name, service_id, top25_v1, top25_v2, change_top25, mean_rank_v1, mean_rank_v2 from v_robust_v1_v2',
'dim_service_ops':'select service_id, stroke_unit_beds_total, tia_clinic_flag, tia_clinic_days_week, tia_inpatient_timescale, tia_outpatient_timescale, first72h_care_onsite, case_ascertainment_72h, suppressed_flag from v_master_clean where analysis_scope=\'INCLUDE\'',
'fact_shortlist':'select * from v_shortlist order by rank_balanced',
'view_icb_rollup':'select * from v_icb_rollup','view_glh_rollup':'select * from v_glh_rollup','view_category_summary':'select * from v_category_summary'}
for n,q in items.items():
    cur=con.execute(q); cols=[d[0] for d in cur.description]; rows=cur.fetchall()
    with open(f'powerbi/data/{n}.csv','w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(cols); w.writerows(rows)
    print(n,len(rows))
