-- Coherence entre couches : les trois tables GOLD doivent retrouver le chiffre
-- d'affaires total de SILVER (a l'arrondi pres). Le test echoue s'il renvoie une ligne.

with silver as (
    select round(sum(sales), 2) as total_sales from {{ ref('curation_sales') }}
),

gold as (
    select 'agg_sales_by_region' as model_name, sum(total_sales) as total_sales
    from {{ ref('agg_sales_by_region') }}
    union all
    select 'agg_sales_by_category', sum(total_sales)
    from {{ ref('agg_sales_by_category') }}
    union all
    select 'agg_monthly_sales', sum(total_sales)
    from {{ ref('agg_monthly_sales') }}
)

select gold.model_name, gold.total_sales as gold_total, silver.total_sales as silver_total
from gold
cross join silver
where abs(gold.total_sales - silver.total_sales) > 1
