-- GOLD : chiffre d'affaires, benefice et nombre de commandes par mois de commande.

select
    date_trunc('month', order_date)::date                 as order_month,
    round(sum(sales), 2)                                  as total_sales,
    round(sum(profit), 2)                                 as total_profit,
    count(distinct order_id)                              as nb_orders
from {{ ref('curation_sales') }}
group by 1
order by 1
