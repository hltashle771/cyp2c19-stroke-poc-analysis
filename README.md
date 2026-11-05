# Genedrive CYP2C19 portfolio: SQL repository and Power BI package

Independent analysis of where rapid point-of-care (POC) CYP2C19 testing could fit in English stroke services.
Public sources only (SSNAP, NHS England, NICE HTG724); not commissioned by Genedrive. Revenue figures are **addressable if adopted, not forecasts**.

- **Question:** which of 98 English stroke services most suit rapid POC CYP2C19 testing rather than lab-only testing.
- **Answer:** Northwick Park, York and Royal Stoke stay in the top seven under all three weightings tested.
- **Limit:** public data cannot show local laboratory turnaround, the one input that could change the ranking. For most services the evidence to say more does not yet exist.

Code is MIT-licensed. The data comes from the public sources above, each with its own terms.

## Contents
| path | what |
|---|---|
| `export_tables.py` | reads the recalculated workbook and writes tidy CSVs to `data/` |
| `data/*.csv` | 14 tables (dimensions, facts, scenarios in long format, evidence, sources, assumptions) |
| `sql/01_schema.sql` | DDL: keys, foreign keys, checks (SQLite; plain ANSI-style) |
| `sql/02_views.sql` | reporting views: service, ICB, GLH, category, priority tier, thrombectomy split |
| `sql/03_analysis.sql` | score recompute, weight robustness, break-even leakage, evidence uplift |
| `sql/04_tests.sql` | reconciliation tests (table `test_results`; 50 tests across the whole build, all passing) |
| `sql/05_powerbi_views.sql` | flat views for Power BI |
| `workbook/` | the Excel model the tables are exported from |
| `build_db.py` | creates `genedrive.db`, loads data, draws seeded weights, runs the SQL in order |
| `export_for_powerbi.py` | writes `powerbi/data/*.csv` |
| `queries/business_questions.sql` | sixteen runnable business questions (Q1 to Q16) |
| `powerbi/` | `model.md`, `measures.dax`, `pages.md`, `theme.json`, `data/` |

## Run it
```
python3 export_tables.py workbook/Genedrive_CYP2C19_Economics_Scoring_v1_0.xlsx   # only if the workbook changes
python3 build_db.py                                                         # builds genedrive.db (not stored in the repo), runs tests
python3 export_for_powerbi.py
sqlite3 genedrive.db "select * from test_results where pass = 0"           # must return no rows
```

## Method notes
- **Reconciliation.** The three lens scores and ranks are recomputed in SQL from the component scores and weights and must match the workbook exactly. Totals (tests, flat revenue, category-adjusted revenue, shortlist size, rank spread) are compared with the workbook's own summary cells. A mutation check (changing a revenue and a rank) is caught by the tests.
- **Weight robustness.** 4,000 seeded weight sets: 2,000 uniform on the simplex and 2,000 with every weight at least 5%. For each site the database records top-10 and top-25 rates and rank percentiles. Seed 42; reproducible.
- **Break-even leakage.** The share of loss-of-function patients who are never switched because the lab result arrives too late to act on, which the lab route must reach for whole-site POC to cost no more than a given amount per extra stroke avoided (5 years, working switch mix). The money grid (10k to 100k) is **hypothetical**; it is not a NICE threshold.
- **Neutral scoring.** Sites with no evidence are scored 50 on that component, never low. 89 of 98 services have no timing evidence (after the six validation overrides).
- **Counts.** 98 services; 95 greenfield; 94 ranked with demand data. Leeds General Infirmary is greenfield but SSNAP reports "too few to report", so it has no demand, tests, rank or revenue (it sits in the evidence-needed group at GBP 0). The three incumbents (Peterborough, Salford, Bristol and Weston) are not ranked.
- **Uptake does not change rank.** Every site's tests are its annual ischaemic stroke count times the same constant (0.601 in the Central scenario), so uptake shares set the scale of tests, revenue and the 300-test POC-led threshold, not the demand ranking.
- **Stay/TIA mix (70/30).** Re-ranking at 50/50 to 100/0: the Balanced top three (Northwick Park, York, Royal Stoke) is unchanged, the top 10 keeps 8 to 10 sites under all three lenses, and the seven shortlisted sites move at most 6 places. It is an analyst assumption, low impact for the top sites and moderate mid-table (assumption 27).

## Findings from the SQL layer (Central scenario)
1. **Break-even leakage is nearly the same at every site** (9.7% to 13.1% at a hypothetical 50k per extra stroke; 26% at 20k; 51% at 10k). Premium per loss-of-function patient found is about 166 to 225 everywhere, so site volume scales the pot but does not change the economics. Site differences have to come from local leakage, which only evidence can supply.
2. **York and Royal Stoke are the most weighting-proof sites.** Under random weights York is in the top 10 in 99.8% of draws, Royal Stoke in 96%; Northwick Park 82% (its top rank depends on the fit weighting), Dorset 60%, King's 44%, East Kent 32%, Leicester 6%. Caution: York ranks high on volume and a short stay with timing unknown, so part of its robustness is neutral scoring plus volume.
3. **The workbook shortlist (30 sites) missed little.** Only three sites outside it reach the top 25 in more than 20% of free draws (Royal Hampshire 32%, Broomfield 24%, Northampton 21%).
4. **Value of evidence.** Moving every evidence-needed site from the flat 25% share to the 10% default removes about £486k a year of addressable revenue; the five sites with most at stake are Dorset, Royal Victoria Infirmary, Stepping Hill, Queen Elizabeth Birmingham and Royal Derby (about 9k to 10k each).

## Limits
- SQLite is the working engine here; the DDL ports to PostgreSQL or SQL Server with minor edits (window functions and CTEs are standard).
- The Power BI report (five pages, see `powerbi/pages.md`) was built and audited in Power BI Desktop outside this repo; the model, measures and theme here specify it. Check each measure against the figure in its comment.
- Values come from the workbook's cached results (recalculated in LibreOffice). Re-run `export_tables.py` after any workbook change.
- Open owner checks: the Leicester source conflict (its Balanced rank is 7 / 21 / 24 if readiness is High / Medium / Unknown; category unchanged), a sourced antiplatelet switch mix (break-even at 50k per stroke ranges 7.8% to 11.3% across mixes; see the methodology note), and the NICE template units labelling (next point). The master workbook has been rebuilt around the v1.0 model, so Peterborough as incumbent and the six validation overrides are in it. None of this changes a figure here: the model already applies them. See workbook `00_MY_SUMMARY`.
- NICE's template labels its fixed-cost cells (Financial impact (cash) D23, E27) as GBP 000 but holds 2,033 and 750 unscaled. This repo works in pounds and is unaffected; do not quote NICE's fixed-cost line.
- Revenue basis: GBP 694,101 (category shares) and GBP 1,207,071 (flat 25%) cover the 94 greenfield services with demand data. The workbook's 08E base of GBP 1,268,896 also includes the three incumbents (GBP 61,825).

## Raw master layer (added)
`python3 export_master_raw.py <master.xlsx>` writes `data/raw/*.csv` (all text, with `src_row` = Excel row). `sql/00_raw_schema.sql` creates `raw_*` tables (master 40 columns, GLH region + trust mapping, ICB lookup, commercial intel, Stage 2, clinical, OA, crosswalk, dictionary). `sql/06_master_clean_views.sql` adds typed views (`v_master_clean`, `v_service_master`, `v_stage2_clean`, `v_glh_reference`, `v_glh_conflicts`) with guarded casts: SSNAP codes such as "Too few to report" and "." become NULL. `sql/07_raw_tests.sql` reconciles the model tables to the master (40/40 tests pass). Not loaded: `ets` (46k rows), `ETR_DATAinsert`, `05A`, `07_QA`, `10_ANALYSIS_STAGE1`.

## Extended scoring (v2, hypothesis layer)
`sql/08_extended_scoring.sql` adds TIA timescale and TIA clinic days to time-sensitivity (bands in `dim_timescale_band`, `dim_clinic_days_band`; sub-weights in `dim_ts_weight`). The workbook (v1) is untouched. Test: with v1 sub-weights the v2 engine reproduces the workbook exactly. Compare with `v_v1_v2_rank`, `v_variant_sensitivity`, `v_robust_v1_v2` (queries Q14-Q16). Bands and weights are judgement, not evidence. Categories and revenue are NOT recomputed under v2.
