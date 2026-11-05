# Power BI data model

Load every file in `powerbi/data/` (Get data > Text/CSV, or Folder). Keep the table names as the file names.

## Relationships (all single direction, dim to fact)
| from (one) | to (many) | column |
|---|---|---|
| dim_icb | dim_service | icb_id |
| dim_service | fact_score | service_id |
| dim_service | fact_service_metrics | service_id |
| dim_service | fact_cost | service_id |
| dim_service | fact_scenario | service_id |
| dim_scenario | fact_scenario | scenario |
| dim_service | fact_robustness | service_id |
| dim_service | fact_leakage_grid | service_id |
| dim_service | fact_evidence_uplift | service_id |

`dim_lens` is deliberately **disconnected**: it only drives the lens slicer used by the `Rank (selected lens)` and `Score (selected lens)` measures.
`fact_breakeven_national`, `fact_calibration`, `fact_evidence`, `dim_assumption`, `dim_source`, `fact_override` and the three `view_*` tables stand alone (pre-aggregated or lookup tables).

## Settings
- `fact_score[category]`: sort by `category_sort`.
- Hide key columns (`service_id`, `icb_id`) on fact tables.
- Formats: revenue as £ #,##0; shares as 0%; scores 0.0; ranks whole number.
- Default `dim_scenario` slicer to Central; default `fact_robustness[set_name]` slicer to free.
- Greenfield view: page-level filter `dim_service[greenfield_flag] = 1` on ranking visuals (incumbents have no rank).

## Why CSVs and not a live database
The database is SQLite. Power BI has no native SQLite connector, so the CSV exports are the dependable route. If you move the schema to PostgreSQL or SQL Server (`sql/01_schema.sql` is plain DDL), point Power BI at the same table and view names and the measures work unchanged.

## v2 tables (added with the extended scoring)
| from (one) | to (many) | column |
|---|---|---|
| dim_service | fact_rank_v2 | service_id |
| dim_service | fact_robust_v1_v2 | service_id |
| dim_service | dim_service_ops | service_id |

`fact_rank_v2` has one row per service per lens (v1 rank, v2 rank, places gained); filter it with the same lens slicer (`lens_name`). `fact_variant_sensitivity` stands alone. v2 is a hypothesis layer: label it that way on any page that shows it.
