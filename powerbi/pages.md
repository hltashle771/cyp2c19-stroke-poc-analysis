# Report pages (build plan)

Apply `theme.json` (View > Themes > Browse). Use one filled colour per category, kept the same on every page:
POC-led = blue, Hybrid = green, Evidence needed (research priority) = amber, Evidence needed (lower priority) = grey, Lab-led = vermillion, Incumbent = dark grey.
Every page carries a footer text box: "Addressable revenue if adopted, not a forecast. Public sources only. Independent analysis."

## 1. Overview
- Cards: Services, Greenfield Services, Tests (selected scenario), Revenue Category-Adjusted, Revenue Flat 25pc, Candidate Sites, Evidence Coverage.
- Bar: services by category (sorted by category_sort). Slicer: scenario.
- Message: most sites are "evidence needed"; the headline revenue gap between flat and category-adjusted is the cost of not knowing the route.

## 2. Site ranking
- Slicer: lens (dim_lens), plus Priority and GLH.
- Table: site, ICB, Rank (selected lens), Score (selected lens), category, timing evidence, tests.
- Scatter: Tests (selected scenario) vs Score; bubble colour = category.
- Bar: Top 10 Rate by site (robustness), slicer set_name. Shows which top ranks survive random weightings.

## 3. Speed case
- Line: Break-even Leakage (national) by willingness-to-pay (`fact_breakeven_national[gbp_per_stroke_avoided]`). Label the axis "hypothetical value per extra stroke avoided".
- Matrix: leakage (5/10/25/50%) by site category with Premium per Extra Stroke.
- Cards: Premium per LOF Patient, Premium if Whole Site Used POC.
- Message: the break-even leakage is almost the same at every site, so site differences come from local leakage (timing), which only evidence can supply.

## 4. Commissioners
- Matrix from `view_icb_rollup`: ICB, services, revenue, candidates, evidence coverage (conditional-format data bars).
- Matrix from `view_glh_rollup`.
- Message: biggest ICB pots are multi-site and evidence-poor.

## 5. Evidence and calibration
- Table: `fact_evidence_uplift` (revenue at stake) top 15.
- Clustered column: Salford observed vs model Limited / Central / Higher.
- Table: `fact_calibration` loss-of-function sources with interval vs the model value (reference line at 32.1%).
- Table: `dim_assumption` filtered to impact = High.
