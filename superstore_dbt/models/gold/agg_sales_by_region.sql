-- GOLD : chiffre d'affaires, benefice et nombre de commandes par region.

select
    region,
    round(sum(sales), 2)                                  as total_sales,
    round(sum(profit), 2)                                 as total_profit,
    count(distinct order_id)                              as nb_orders,
    round(sum(profit) / nullif(sum(sales), 0), 4)         as profit_margin
from {{ ref('curation_sales') }}
group by region
order by total_sales desc
