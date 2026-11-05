"""Build genedrive.db from data/*.csv and run the SQL scripts in order.
Usage: python3 build_db.py   (from the repo root)."""
import sqlite3, csv, os, random, sys
DB='genedrive.db'
if os.path.exists(DB): os.remove(DB)
con=sqlite3.connect(DB); cur=con.cursor()
cur.executescript(open('sql/01_schema.sql').read())
cur.executescript(open('sql/00_raw_schema.sql').read())
def load(table,fname=None):
    with open(f'data/{fname or table}.csv',newline='',encoding='utf-8') as f:
        r=csv.reader(f); hdr=next(r); rows=[[None if v=='' else v for v in row] for row in r]
    q=','.join('?'*len(hdr)); cols=','.join(f'"{h}"' for h in hdr)
    cur.executemany(f'INSERT INTO {table}({cols}) VALUES ({q})',rows)
for f in sorted(os.listdir('data/raw')):
    load(f[:-4], 'raw/'+f[:-4])
cur.executemany('INSERT INTO dim_scenario VALUES (?,?)',[('Limited',1),('Central',2),('Higher',3)])
for t in ['dim_icb','dim_service','fact_service_metrics','fact_scenario','fact_cost','fact_score','dim_lens','fact_override','dim_parameter','dim_assumption','dim_source','fact_evidence','fact_calibration','shortlist_notes']: load(t)
cur.executemany('INSERT INTO workbook_checks VALUES (?,?)',list(csv.reader(open('data/workbook_checks.csv')))[1:])
# Monte Carlo weight draws: seeded, reproducible. 'free' = uniform on the simplex (Dirichlet(1,1,1,1));
# 'floor5' = every weight at least 5% (0.05 + 0.80 * Dirichlet).
random.seed(42)
def dirichlet():
    g=[random.gammavariate(1,1) for _ in range(4)]; s=sum(g); return [x/s for x in g]
rows=[]
for set_name,floor in (('free',0.0),('floor5',0.05)):
    for i in range(1,2001):
        d=dirichlet(); w=[floor+(1-4*floor)*x for x in d]; rows.append((set_name,i,*w))
cur.executemany('INSERT INTO weight_draw VALUES (?,?,?,?,?,?)',rows)
cur.executemany('INSERT INTO dim_wtp VALUES (?,?,?)',[(1,'hypothetical grid: low',10000),(2,'hypothetical grid',20000),(3,'hypothetical grid',30000),(4,'hypothetical grid',50000),(5,'hypothetical grid: high',100000)])
con.commit()
for f in sorted(os.listdir('sql')):
    if f.startswith(('00_','01_')): continue
    if f.endswith('.sql'):
        cur.executescript(open('sql/'+f).read()); con.commit(); print('ran',f)
con.close()
