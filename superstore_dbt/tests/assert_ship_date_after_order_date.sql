-- Une commande ne peut pas etre expediee avant d'avoir ete passee.

select row_id, order_date, ship_date, delivery_days
from {{ ref('curation_sales') }}
where ship_date is null
   or delivery_days < 0
