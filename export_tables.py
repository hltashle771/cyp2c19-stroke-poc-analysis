"""Export tidy tables from the recalculated v1.0 workbook into data/*.csv.
Run: python3 export_tables.py path/to/Genedrive_CYP2C19_Economics_Scoring_v1_0.xlsx
Values are the cached results of the workbook formulas (recalculated in LibreOffice)."""
import sys, csv, re, os, openpyxl
wbp=sys.argv[1] if len(sys.argv)>1 else 'Genedrive_CYP2C19_Economics_Scoring_v1_0.xlsx'
wb=openpyxl.load_workbook(wbp,data_only=True)
os.makedirs('data',exist_ok=True)
def num(x):
    if x is None or x=='' : return None
    if isinstance(x,(int,float)): return x
    try: return float(str(x).replace(',',''))
    except: return None
def w(name,header,rows):
    with open(f'data/{name}.csv','w',newline='',encoding='utf-8') as f:
        c=csv.writer(f); c.writerow(header); c.writerows(rows)
    print(name,len(rows))
def rows(ws,r0,r1,ncols):
    for r in range(r0,r1+1):
        yield [ws.cell(r,c).value for c in range(1,ncols+1)]
S=wb['08S_SERVICES']; B=wb['08B_ECON_DEMAND']; C=wb['08C_ECON_COSTS']; V=wb['08D_GENEDRIVE_VIEW']; A=wb['12A_SCORING']; D=wb['12_SCORE_DATA']
# dim_icb
icbs=sorted({S.cell(r,4).value for r in range(6,104)})
icb_id={n:i for i,n in enumerate(icbs,1)}
def short(n): return re.sub(r'^NHS | INTEGRATED CARE BOARD$','',n).title()
w('dim_icb',['icb_id','icb_name','icb_short'],[(icb_id[n],n,short(n)) for n in icbs])
# dim_service
sd={D.cell(r,1).value:[D.cell(r,c).value for c in (3,4,5,6)] for r in range(6,104)}
out=[]
for r in range(6,104):
    sid=S.cell(r,1).value; thr=1 if str(S.cell(r,9).value).upper()=='YES' else 0
    gf=int(S.cell(r,14).value); t=sd[sid]
    out.append((sid,S.cell(r,2).value,S.cell(r,3).value,icb_id[S.cell(r,4).value],S.cell(r,5).value,S.cell(r,11).value,S.cell(r,12).value,S.cell(r,13).value,thr,gf,1-gf,t[0],t[1],t[2],t[3]))
w('dim_service',['service_id','service_name','trust','icb_id','glh_region','stage2_priority','genedrive_status','competitive_position','thrombectomy_flag','greenfield_flag','incumbent_flag','stage2_timing_evidence','stage2_readiness','commercial_archetype','critical_next_question'],out)
# fact_service_metrics
out=[]
for r in range(6,104):
    sid=S.cell(r,1).value
    out.append((sid,num(B.cell(r,3).value),num(B.cell(r,4).value),num(B.cell(r,5).value),num(B.cell(r,6).value),num(B.cell(r,7).value),num(S.cell(r,7).value),num(S.cell(r,8).value),num(S.cell(r,10).value)))
w('fact_service_metrics',['service_id','quarterly_ischaemic','annual_ischaemic','nonminor_strokes','minor_strokes','tia_proxy','median_stay_days','tia_wait_days','tia_final_diagnoses'],out)
# fact_scenario (long)
out=[]
for r in range(6,104):
    sid=S.cell(r,1).value
    for k,sc in enumerate(['Limited','Central','Higher']):
        out.append((sid,sc,num(B.cell(r,8+k).value),num(B.cell(r,11+k).value),num(V.cell(r,9+k).value),num(V.cell(r,12+k).value),num(V.cell(r,15+k).value),num(V.cell(r,18+k).value)))
w('fact_scenario',['service_id','scenario','tests','lof_patients_found','poc_tests_flat25','kit_revenue','fixed_revenue','total_revenue'],out)
# fact_cost (Central)
hdr=['service_id']+['tests_central','lab_test_cash','lab_staff','poc_test_cash','poc_staff','hybrid_test_cash','hybrid_staff','poc_premium_over_lab','lof_patients','premium_per_lof','drug_cost_all_ticagrelor','drug_cost_all_dipasp','drug_cost_working_mix','strokes_avoided_5y_ticagrelor','strokes_avoided_5y_dipasp','strokes_avoided_5y_working','strokes_avoided_90d_ticagrelor','strokes_avoided_90d_dipasp','strokes_avoided_90d_working','incremental_cash_vs_no_testing','cash_per_stroke_avoided_5y','extra_strokes_avoided_if_poc_recovers_leakage','poc_premium_per_extra_stroke']
out=[[C.cell(r,1).value]+[num(C.cell(r,c).value) for c in range(3,26)] for r in range(6,104)]
w('fact_cost',hdr,out)
# fact_score
cols=['timing_adj','readiness_adj','demand_score','stay_score','tia_speed_score','time_sensitivity_score','poc_suitability_score','readiness_score','data_gaps','score_balanced','score_volume','score_fit','rank_balanced','rank_volume','rank_fit','best_rank','worst_rank','rank_spread','in_top_n','on_shortlist','category','poc_share','revenue_category_adjusted','revenue_flat25','revenue_change']
out=[]
for r in range(6,104):
    row=[A.cell(r,1).value,A.cell(r,10).value,A.cell(r,11).value]+[num(A.cell(r,c).value) for c in range(12,30)]+[A.cell(r,30).value,num(A.cell(r,31).value),num(A.cell(r,32).value),num(A.cell(r,33).value),num(A.cell(r,34).value)]
    out.append(row)
w('fact_score',['service_id']+cols,out)
# dim_lens (weights)
I=wb['12_SCORE_INPUTS']
lens=[(1,'Balanced'),(2,'Volume-led'),(3,'Fit-led')]
out=[(i,n,I.cell(5,1+i).value,I.cell(6,1+i).value,I.cell(7,1+i).value,I.cell(8,1+i).value) for i,n in lens]
w('dim_lens',['lens_id','lens_name','w_demand','w_time_sensitivity','w_poc_suitability','w_readiness'],out)
# fact_override
out=[(I.cell(r,1).value,I.cell(r,3).value,I.cell(r,4).value,I.cell(r,5).value,I.cell(r,6).value) for r in range(46,56) if I.cell(r,1).value]
w('fact_override',['service_id','timing_override','readiness_override','reason','evidence_id'],out)
# dim_parameter (08A)
P=wb['08A_ECON_INPUTS']; out=[]
for r in range(5,30):
    if isinstance(P.cell(r,1).value,int): out.append((P.cell(r,1).value,P.cell(r,2).value,P.cell(r,3).value,num(P.cell(r,4).value),num(P.cell(r,5).value),num(P.cell(r,6).value),P.cell(r,7).value,P.cell(r,8).value,P.cell(r,9).value))
w('dim_parameter',['param_id','parameter','unit','limited','central','higher','source_type','source_reference','status'],out)
# dim_assumption
X=wb['10_ASSUMPTIONS']; out=[]
for r in range(5,X.max_row+1):
    if X.cell(r,2).value: out.append((len(out)+1,X.cell(r,1).value,X.cell(r,2).value,X.cell(r,6).value,X.cell(r,7).value,X.cell(r,8).value))
w('dim_assumption',['assumption_id','where','assumption','status','impact','what_would_change_it'],out)
# dim_source, fact_evidence
R=wb['09_SOURCE_REGISTER']; out=[tuple(R.cell(r,c).value for c in range(1,10)) for r in range(5,R.max_row+1) if R.cell(r,1).value]
w('dim_source',['source_id','type','title','publisher','url_or_file','date','reliability','used_for','caveat'],out)
E=wb['12D_EVIDENCE_LOG']; out=[tuple(E.cell(r,c).value for c in range(1,6)) for r in range(5,E.max_row+1) if E.cell(r,1).value]
w('fact_evidence',['evidence_id','finding','source','reliability','used_for'],out)
# fact_calibration
K=wb['13_CALIBRATION']; out=[]
out.append(('volume','Salford annualised observed tests',num(K['B8'].value),None,None,None))
for lab,r in (('Limited',10),('Central',11),('Higher',12)): out.append(('volume','Salford model tests '+lab,num(K.cell(r,2).value),None,None,None))
for r in range(21,27): out.append(('lof',K.cell(r,1).value,num(K.cell(r,3).value),num(K.cell(r,2).value),num(K.cell(r,4).value),num(K.cell(r,5).value)))
w('fact_calibration',['block','label','value','n','ci_low','ci_high'],out)
# workbook_checks: independent expected totals read from the workbook summary sheets
H=wb['12C_SUMMARY']
def find(ws,prefix,col=2):
    for r in range(1,ws.max_row+1):
        v=ws.cell(r,1).value
        if isinstance(v,str) and v.startswith(prefix): return num(ws.cell(r,col).value)
chk=[('tests_central_total',num(B['I4'].value)),('greenfield_flat25_revenue_total',num(V['U4'].value)),
('category_adjusted_revenue_total',num(H['E11'].value)),('flat25_revenue_total_12C',num(H['D11'].value)),
('research_shortlist_count',find(H,'on research shortlist')),('top25_all_three_lenses',find(H,'in top N under ALL THREE')),
('largest_rank_spread',find(H,'largest rank spread'))]
w('workbook_checks',['check','expected'],chk)
