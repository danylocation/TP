-- =====================================================================
-- Projet Superstore Sales - Partie 5 : tableau de bord
-- Deploie dashboard/streamlit_app.py en application Streamlit in Snowflake.
-- L'application lit uniquement les tables de SUPERSTORE_DB.GOLD.
-- A lancer avec `python snowflake/deployer_dashboard.py` (PUT compris).
-- =====================================================================

USE ROLE SYSADMIN;
USE WAREHOUSE SUPERSTORE_WH;
USE DATABASE SUPERSTORE_DB;

CREATE STAGE IF NOT EXISTS PUBLIC.STG_DASHBOARD
  COMMENT = 'Code du tableau de bord Streamlit';

PUT 'file://dashboard/streamlit_app.py' @PUBLIC.STG_DASHBOARD/dashboard
  AUTO_COMPRESS = FALSE OVERWRITE = TRUE;

CREATE OR REPLACE STREAMLIT PUBLIC.DASHBOARD_SUPERSTORE
  FROM '@SUPERSTORE_DB.PUBLIC.STG_DASHBOARD/dashboard'
  MAIN_FILE = 'streamlit_app.py'
  QUERY_WAREHOUSE = SUPERSTORE_WH
  -- Execution sur l'entrepot (paquets Streamlit, pandas et altair fournis),
  -- plutot que sur le pool de conteneurs propose par defaut
  RUNTIME_NAME = 'SYSTEM$WAREHOUSE_RUNTIME'
  TITLE = 'Superstore Sales'
  COMMENT = 'Tableau de bord des ventes, couche GOLD';

SHOW STREAMLITS IN SCHEMA SUPERSTORE_DB.PUBLIC;
