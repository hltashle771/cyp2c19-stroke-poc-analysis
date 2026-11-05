"""Export raw master sheets to data/raw/*.csv (all values as text, source row numbers kept)."""
import openpyxl, csv, re, datetime, sys
SRC=sys.argv[1] if len(sys.argv)>1 else '/mnt/user-data/uploads/Genedrive_CYP2C19_Master_v0_1_20261008-105202_.xlsx'
wb=openpyxl.load_workbook(SRC,data_only=True)
# (sheet, table, header_row, first_col, last_col)
SPEC=[('06_MASTER','raw_master',1,1,40),('REF_GLH','raw_glh_region',1,1,4),('REF_GLH','raw_glh_trust',1,6,11),
('REF_ICB_2026','raw_icb_lookup',1,1,2),('05_COMMERCIAL_INTEL','raw_commercial',1,1,23),
('11_STAGE2_SYNTHESIS','raw_stage2',9,1,19),('02_CLINICAL_EXTRACT','raw_clinical',1,1,12),
('03_OA_extract','raw_oa',1,1,17),('04_SERVICE_CROSSWALK','raw_crosswalk',1,1,7),('01_DATA_DICTIONARY','raw_dictionary',1,1,13)]
def clean(h,seen):
    h=re.sub(r'[^0-9a-z]+','_',str(h or '').strip().lower()).strip('_') or 'col'
    if h[0].isdigit(): h='c_'+h
    base,n=h,1
    while h in seen: n+=1; h=f'{base}_{n}'
    seen.add(h); return h
def txt(v):
    if v is None: return ''
    if isinstance(v,(datetime.datetime,datetime.date)): return v.date().isoformat() if hasattr(v,'date') else v.isoformat()
    if isinstance(v,float): return repr(v)
    return str(v).strip()
counts={}
for sh,tb,hr,c1,c2 in SPEC:
    ws=wb[sh]; seen=set(); hdr=[clean(ws.cell(hr,c).value,seen) for c in range(c1,c2+1)]
    rows=[]
    for r in range(hr+1,ws.max_row+1):
        vals=[txt(ws.cell(r,c).value) for c in range(c1,c2+1)]
        if any(vals): rows.append([r]+vals)
    with open(f'data/raw/{tb}.csv','w',newline='',encoding='utf-8') as f:
        w=csv.writer(f); w.writerow(['src_row']+hdr); w.writerows(rows)
    counts[tb]=len(rows); print(tb,len(rows),hdr[:4],'...')
