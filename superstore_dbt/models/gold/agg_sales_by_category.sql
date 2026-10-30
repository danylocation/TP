-- GOLD : chiffre d'affaires, benefice et quantite vendue par categorie.

select
    category,
    round(sum(sales), 2)                                  as total_sales,
    round(sum(profit), 2)                                 as total_profit,
    sum(quantity)                                         as total_quantity,
    round(sum(profit) / nullif(sum(sales), 0), 4)         as profit_margin
from {{ ref('curation_sales') }}
group by category
order by total_sales desc
