# Power BI: first session (Windows)

Goal for session 1: install Power BI Desktop, load three tables, connect them, and build one chart. Nothing else.

1. Install: Microsoft Store > "Power BI Desktop" (free). Open it, choose a blank report.
2. Load: Home > Get data > Text/CSV. Load `data/dim_service.csv`, `data/fact_score.csv`, `data/dim_icb.csv`. For each, click Load (not Transform).
3. Model view (the middle icon on the left bar). Check there is a line from dim_icb[icb_id] to dim_service[icb_id], and from dim_service[service_id] to fact_score[service_id]. If a line is missing, drag the column across. "One to many" and "single" direction is correct.
4. Report view. Add a Table visual with dim_service[service_name], fact_score[rank_balanced], fact_score[category]. Sort by rank_balanced ascending.
5. Add a bar chart: Axis = fact_score[category], Values = count of dim_service[service_id].
6. Save as `genedrive_v0.pbix`.

Check: the table's top row should be Northwick Park Hospital HASU with rank 1. If it is not, tell me what you see.

Then continue with `model.md` (remaining tables), `measures.dax` (measures) and `pages.md` (page plan).
