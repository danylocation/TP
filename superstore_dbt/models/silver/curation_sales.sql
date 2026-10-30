-- SILVER : ventes nettoyees, typees et dedoublonnees, une ligne par ligne de commande.

with source as (

    select * from {{ source('raw', 'sales') }}

),

-- Renommage en snake_case et typage. try_to_* renvoie NULL au lieu d'echouer
-- si une valeur est mal formee : ces lignes sont ensuite ecartees ou testees.
typed as (

    select
        try_to_number("Row ID")                               as row_id,
        nullif(trim("Order ID"), '')                          as order_id,
        try_to_date("Order Date", 'MM/DD/YYYY')               as order_date,
        try_to_date("Ship Date", 'MM/DD/YYYY')                as ship_date,
        nullif(trim("Ship Mode"), '')                         as ship_mode,
        nullif(trim("Customer ID"), '')                       as customer_id,
        nullif(trim("Customer Name"), '')                     as customer_name,
        nullif(trim("Segment"), '')                           as segment,
        nullif(trim("Country"), '')                           as country,
        nullif(trim("City"), '')                              as city,
        nullif(trim("State"), '')                             as state,
        -- Le CSV a perdu le zero initial des codes postaux du nord-est (5408 -> 05408)
        lpad(nullif(trim("Postal Code"), ''), 5, '0')         as postal_code,
        nullif(trim("Region"), '')                            as region,
        nullif(trim("Product ID"), '')                        as product_id,
        nullif(trim("Category"), '')                          as category,
        nullif(trim("Sub-Category"), '')                      as sub_category,
        -- Le fichier contient des espaces insecables (CHR(160)) dans certains noms
        nullif(trim(replace("Product Name", chr(160), ' ')), '') as product_name,
        try_to_decimal("Sales", 18, 4)                        as sales,
        try_to_number("Quantity")                             as quantity,
        try_to_decimal("Discount", 5, 4)                      as discount,
        try_to_decimal("Profit", 18, 4)                       as profit,
        _loaded_at                                            as loaded_at
    from source

),

-- Valeurs nulles : une ligne sans identifiant, sans commande ou sans date ne
-- peut pas etre analysee et est ecartee ; les libelles manquants deviennent
-- 'Non renseigne', une remise absente vaut 0.
nulls_handled as (

    select
        row_id,
        order_id,
        order_date,
        ship_date,
        coalesce(ship_mode, 'Non renseigne')                  as ship_mode,
        customer_id,
        coalesce(customer_name, 'Non renseigne')              as customer_name,
        coalesce(segment, 'Non renseigne')                    as segment,
        coalesce(country, 'Non renseigne')                    as country,
        coalesce(city, 'Non renseigne')                       as city,
        coalesce(state, 'Non renseigne')                      as state,
        postal_code,
        coalesce(region, 'Non renseigne')                     as region,
        product_id,
        coalesce(category, 'Non renseigne')                   as category,
        coalesce(sub_category, 'Non renseigne')               as sub_category,
        coalesce(product_name, 'Non renseigne')               as product_name,
        coalesce(sales, 0)                                    as sales,
        quantity,
        coalesce(discount, 0)                                 as discount,
        coalesce(profit, 0)                                   as profit,
        loaded_at
    from typed
    where row_id is not null
      and order_id is not null
      and order_date is not null

),

-- Doublons : deux cas sont traites.
--  1. le meme row_id charge deux fois (rechargement du fichier) ;
--  2. la meme ligne de commande saisie deux fois avec deux row_id differents
--     (toutes les colonnes metier identiques). Le fichier en contient un :
--     row_id 3406 et 3407. On garde le plus petit row_id.
dedup_row_id as (

    select *
    from nulls_handled
    qualify row_number() over (partition by row_id order by loaded_at desc) = 1

),

deduplicated as (

    select *
    from dedup_row_id
    qualify row_number() over (
                partition by order_id, order_date, ship_date, ship_mode, customer_id,
                             postal_code, product_id, sales, quantity, discount, profit
                order by row_id
            ) = 1

)

select
    row_id,
    order_id,
    order_date,
    ship_date,
    -- Delai de livraison en jours entre la commande et l'expedition
    datediff('day', order_date, ship_date)                    as delivery_days,
    ship_mode,
    customer_id,
    customer_name,
    segment,
    country,
    city,
    state,
    postal_code,
    region,
    product_id,
    category,
    sub_category,
    product_name,
    cast(sales as decimal(18, 4))                             as sales,
    quantity,
    cast(discount as decimal(5, 4))                           as discount,
    cast(profit as decimal(18, 4))                            as profit
from deduplicated
