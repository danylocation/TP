-- =====================================================================
-- Projet Superstore Sales - Partie 1 : chargement dans Snowflake (RAW)
-- A executer dans une feuille SQL Snowsight (role SYSADMIN) ou avec
-- `python snowflake/charger_raw.py`, qui execute ce fichier tel quel.
-- =====================================================================

USE ROLE SYSADMIN;

-- Entrepot de calcul dedie, le plus petit, mis en veille apres 60 s
CREATE WAREHOUSE IF NOT EXISTS SUPERSTORE_WH
  WAREHOUSE_SIZE = 'XSMALL'
  AUTO_SUSPEND = 60
  AUTO_RESUME = TRUE
  INITIALLY_SUSPENDED = TRUE;
USE WAREHOUSE SUPERSTORE_WH;

-- 1. Base de donnees
CREATE DATABASE IF NOT EXISTS SUPERSTORE_DB;
USE DATABASE SUPERSTORE_DB;

-- 2. Schemas de l'architecture en couches
CREATE SCHEMA IF NOT EXISTS RAW    COMMENT = 'Donnees brutes, copie fidele du CSV';
CREATE SCHEMA IF NOT EXISTS SILVER COMMENT = 'Donnees nettoyees et typees (dbt)';
CREATE SCHEMA IF NOT EXISTS GOLD   COMMENT = 'Tables agregees pour l''analyse (dbt)';

USE SCHEMA RAW;

-- 3. Import du CSV dans RAW.SALES
-- Le fichier est encode en Windows-1252 (caracteres accentues dans les noms
-- de produits) et certains champs sont entre guillemets car ils contiennent
-- des virgules.
CREATE OR REPLACE FILE FORMAT RAW.FF_SUPERSTORE_CSV
  TYPE = CSV
  FIELD_DELIMITER = ','
  SKIP_HEADER = 1
  FIELD_OPTIONALLY_ENCLOSED_BY = '"'
  ENCODING = 'WINDOWS1252'
  TRIM_SPACE = TRUE
  EMPTY_FIELD_AS_NULL = TRUE
  NULL_IF = ('', 'NULL', 'null');

CREATE STAGE IF NOT EXISTS RAW.STG_SUPERSTORE
  FILE_FORMAT = RAW.FF_SUPERSTORE_CSV
  COMMENT = 'Zone de depot du fichier Superstore.csv';

-- La couche RAW garde les noms et les valeurs du fichier source : toutes les
-- colonnes sont en texte, le typage est fait dans SILVER par dbt.
CREATE OR REPLACE TABLE RAW.SALES (
  "Row ID"        VARCHAR,
  "Order ID"      VARCHAR,
  "Order Date"    VARCHAR,
  "Ship Date"     VARCHAR,
  "Ship Mode"     VARCHAR,
  "Customer ID"   VARCHAR,
  "Customer Name" VARCHAR,
  "Segment"       VARCHAR,
  "Country"       VARCHAR,
  "City"          VARCHAR,
  "State"         VARCHAR,
  "Postal Code"   VARCHAR,
  "Region"        VARCHAR,
  "Product ID"    VARCHAR,
  "Category"      VARCHAR,
  "Sub-Category"  VARCHAR,
  "Product Name"  VARCHAR,
  "Sales"         VARCHAR,
  "Quantity"      VARCHAR,
  "Discount"      VARCHAR,
  "Profit"        VARCHAR,
  _LOADED_AT      TIMESTAMP_LTZ DEFAULT CURRENT_TIMESTAMP(),
  _SOURCE_FILE    VARCHAR
)
COMMENT = 'Superstore Sales, chargement brut du fichier Superstore.csv';

-- Depot du fichier dans le stage. PUT ne fonctionne pas dans Snowsight :
-- soit on lance cette commande depuis SnowSQL ou le script Python, soit on
-- depose le fichier par l'interface (Data > Databases > SUPERSTORE_DB > RAW >
-- Stages > STG_SUPERSTORE > + Files).
PUT 'file://data/Superstore.csv' @RAW.STG_SUPERSTORE AUTO_COMPRESS = TRUE OVERWRITE = TRUE;

COPY INTO RAW.SALES (
  "Row ID", "Order ID", "Order Date", "Ship Date", "Ship Mode", "Customer ID",
  "Customer Name", "Segment", "Country", "City", "State", "Postal Code",
  "Region", "Product ID", "Category", "Sub-Category", "Product Name",
  "Sales", "Quantity", "Discount", "Profit", _SOURCE_FILE
)
FROM (
  SELECT $1, $2, $3, $4, $5, $6, $7, $8, $9, $10, $11, $12, $13, $14, $15,
         $16, $17, $18, $19, $20, $21, METADATA$FILENAME
  FROM @RAW.STG_SUPERSTORE
)
FILE_FORMAT = (FORMAT_NAME = RAW.FF_SUPERSTORE_CSV)
ON_ERROR = 'ABORT_STATEMENT'
FORCE = TRUE;

-- 4. Verifications
-- Nombre de lignes (attendu : 9 994)
SELECT COUNT(*) AS NB_LIGNES FROM RAW.SALES;

-- Echantillon
SELECT * FROM RAW.SALES ORDER BY TO_NUMBER("Row ID") LIMIT 10;

-- Controles rapides : identifiants vides, commandes distinctes, periode couverte
SELECT
  COUNT_IF("Row ID" IS NULL)   AS ROW_ID_NULS,
  COUNT_IF("Order ID" IS NULL) AS ORDER_ID_NULS,
  COUNT(DISTINCT "Order ID")   AS NB_COMMANDES,
  MIN(TRY_TO_DATE("Order Date", 'MM/DD/YYYY')) AS PREMIERE_COMMANDE,
  MAX(TRY_TO_DATE("Order Date", 'MM/DD/YYYY')) AS DERNIERE_COMMANDE
FROM RAW.SALES;
