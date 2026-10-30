-- Verifications apres `dbt build`, a lancer dans Snowsight (captures du rendu).
USE ROLE SYSADMIN;
USE WAREHOUSE SUPERSTORE_WH;
USE DATABASE SUPERSTORE_DB;

-- Les 5 tables des trois couches et leur nombre de lignes
SELECT table_schema, table_name, table_type, row_count
FROM SUPERSTORE_DB.INFORMATION_SCHEMA.TABLES
WHERE table_schema IN ('RAW', 'SILVER', 'GOLD')
ORDER BY CASE table_schema WHEN 'RAW' THEN 1 WHEN 'SILVER' THEN 2 ELSE 3 END, table_name;

-- RAW : 9 994 lignes brutes
SELECT * FROM RAW.SALES LIMIT 10;

-- SILVER : 9 993 lignes typees, avec le delai de livraison
SELECT row_id, order_id, order_date, ship_date, delivery_days, region, category,
       product_name, sales, quantity, discount, profit
FROM SILVER.CURATION_SALES
ORDER BY row_id
LIMIT 10;

-- GOLD
SELECT * FROM GOLD.AGG_SALES_BY_REGION;
SELECT * FROM GOLD.AGG_SALES_BY_CATEGORY;
SELECT * FROM GOLD.AGG_MONTHLY_SALES ORDER BY order_month;
