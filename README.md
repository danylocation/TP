# Superstore Sales : Data Warehouse avec Snowflake et dbt

Projet individuel, Master 2 DATA, INGETIS. Auteur : ABDUL MALAK Dany.

Dépôt Git : https://github.com/danylocation/TP

Le projet charge le fichier `Superstore.csv` dans Snowflake, le nettoie avec dbt et produit trois tables agrégées pour l'analyse commerciale. Ces tables alimentent ensuite un dashboard Power BI.

## Architecture

```
SUPERSTORE_DB
├── RAW
│   └── SALES                    copie brute du CSV (script SQL)
├── SILVER
│   └── CURATION_SALES           données nettoyées et typées (dbt)
└── GOLD
    ├── AGG_SALES_BY_REGION      CA, bénéfice, commandes par région (dbt)
    ├── AGG_SALES_BY_CATEGORY    CA, bénéfice, quantité par catégorie (dbt)
    └── AGG_MONTHLY_SALES        CA, bénéfice, commandes par mois (dbt)
```

## Contenu du dépôt

| Chemin | Rôle |
| --- | --- |
| `data/Superstore.csv` | Fichier source unique (Kaggle, 9 994 lignes, encodage Windows-1252) |
| `snowflake/01_setup_et_chargement_raw.sql` | Création de la base, des schémas, du stage et de `RAW.SALES`, chargement et vérifications |
| `snowflake/charger_raw.py` | Exécute le script SQL ci-dessus, y compris la commande `PUT` |
| `snowflake/02_verifications.sql` | Requêtes de contrôle des trois couches après `dbt build` |
| `superstore_dbt/` | Projet dbt : modèles SILVER et GOLD, tests, macros |
| `superstore_dbt/profiles.yml.example` | Modèle de connexion dbt, sans secret |
| `captures/` | Captures d'écran des tables, des tests et du dashboard |

## Étapes de réalisation

### 1. Chargement dans Snowflake (RAW)

Le script `snowflake/01_setup_et_chargement_raw.sql` :

1. crée l'entrepôt `SUPERSTORE_WH` (XSMALL, mis en veille après 60 s) et la base `SUPERSTORE_DB` ;
2. crée les schémas `RAW`, `SILVER` et `GOLD` ;
3. crée un format de fichier CSV (encodage `WINDOWS1252`, champs entre guillemets) et un stage interne, dépose le fichier avec `PUT`, puis le charge dans `RAW.SALES` avec `COPY INTO` ;
4. vérifie le nombre de lignes (9 994), affiche un échantillon et contrôle les identifiants vides.

La table RAW garde les noms de colonnes du fichier (`"Order Date"`, `"Sub-Category"`…). Toutes les colonnes sont en texte, sans aucune transformation : le typage se fait dans SILVER. Deux colonnes techniques sont ajoutées, `_LOADED_AT` et `_SOURCE_FILE`.

Pour exécuter le script depuis le poste :

```bash
python snowflake/charger_raw.py
```

On peut aussi le lancer dans Snowsight après avoir déposé le fichier dans le stage `RAW.STG_SUPERSTORE` par l'interface. Dans ce cas, il faut ignorer la ligne `PUT`.

### 2. Transformation avec dbt (SILVER)

Le modèle `models/silver/curation_sales.sql` est matérialisé en table dans `SILVER`. Il :

- **renomme** les colonnes en `snake_case` (`"Order Date"` → `order_date`, `"Sub-Category"` → `sub_category`…) ;
- **convertit les types** : dates au format `MM/DD/YYYY` en `DATE`, montants en `DECIMAL(18,4)`, quantité et identifiant en entier. Les fonctions `TRY_TO_*` renvoient NULL au lieu d'échouer sur une valeur mal formée ;
- **gère les valeurs nulles** :
  - une ligne sans `row_id`, sans `order_id` ou sans date de commande est écartée ;
  - un libellé manquant devient `Non renseigné` ;
  - une remise ou un montant manquant vaut 0 ;
- **traite les doublons**, de deux sortes :
  - un même `row_id` chargé deux fois, en cas de rechargement : seule la dernière version est gardée ;
  - une même ligne de commande saisie deux fois sous deux `row_id`. Le fichier en contient une, les lignes 3406 et 3407 : le même fauteuil, la même commande, les mêmes montants. On garde la 3406. SILVER compte donc **9 993 lignes** ;
- **calcule le délai de livraison** : `delivery_days = DATEDIFF(day, order_date, ship_date)`, de 0 à 7 jours, 3,96 jours en moyenne ;
- **corrige les codes postaux** : le CSV a perdu le zéro initial de ceux du nord-est des États-Unis. Ils sont remis sur 5 caractères (`5408` → `05408`) ;
- **remplace les espaces insécables** (`CHR(160)`) présents dans certains noms de produits par des espaces normaux.

La macro `macros/generate_schema_name.sql` fait écrire les modèles directement dans `SILVER` et `GOLD`. Sans elle, dbt préfixerait le nom du schéma par celui de la cible.

### 3. Tests de qualité

Les 5 tests demandés sont déclarés dans `models/silver/schema.yml` :

| N° | Test | Type |
| --- | --- | --- |
| 1 | `row_id` non NULL | `not_null` |
| 2 | `row_id` unique | `unique` |
| 3 | `order_id` non NULL | `not_null` |
| 4 | `quantity` strictement positive | test générique personnalisé `strictly_positive` (`tests/generic/`) |
| 5 | `discount` compris entre 0 et 1 | test générique personnalisé `value_between` (`tests/generic/`) |

Tests ajoutés en plus :

- **Sur SILVER et sur la source** :
  - `order_date` non NULL ;
  - régions limitées à Central, East, South et West ;
  - date d'expédition jamais antérieure à la date de commande (`tests/assert_ship_date_after_order_date.sql`) ;
  - `"Row ID"` non NULL dès la table RAW.
- **Sur GOLD** :
  - clés non NULL et uniques dans chaque table ;
  - cohérence entre couches : chaque table GOLD retrouve le chiffre d'affaires total de SILVER (`tests/assert_gold_totals_match_silver.sql`).

Au total, 16 tests. `dbt build` sur Snowflake : 4 modèles créés, 16 tests réussis (`PASS=20 WARN=0 ERROR=0`).

### 4. Tables GOLD

Ces tables sont construites à partir de `curation_sales` et matérialisées dans `GOLD`. Les montants sont arrondis à 2 décimales après l'agrégation, et une commande compte une fois même si elle a plusieurs lignes (`COUNT(DISTINCT order_id)`).

| Table | Grain | Mesures |
| --- | --- | --- |
| `agg_sales_by_region` | région | `total_sales`, `total_profit`, `nb_orders`, `profit_margin` |
| `agg_sales_by_category` | catégorie | `total_sales`, `total_profit`, `total_quantity`, `profit_margin` |
| `agg_monthly_sales` | mois de commande | `total_sales`, `total_profit`, `nb_orders` |

Résultats obtenus dans Snowflake :

| Région | CA ($) | Bénéfice ($) | Commandes | Marge |
| --- | ---: | ---: | ---: | ---: |
| West | 725 457,82 | 108 418,45 | 1 611 | 14,9 % |
| East | 678 499,87 | 91 534,84 | 1 401 | 13,5 % |
| Central | 501 239,89 | 39 706,36 | 1 175 | 7,9 % |
| South | 391 721,91 | 46 749,43 | 822 | 11,9 % |

| Catégorie | CA ($) | Bénéfice ($) | Quantité | Marge |
| --- | ---: | ---: | ---: | ---: |
| Technology | 836 154,03 | 145 454,95 | 6 939 | 17,4 % |
| Furniture | 741 718,42 | 18 463,33 | 8 026 | 2,5 % |
| Office Supplies | 719 047,03 | 122 490,80 | 22 906 | 17,0 % |

`agg_monthly_sales` couvre 48 mois, de janvier 2014 à décembre 2017, et 5 009 commandes. Le chiffre d'affaires total est de 2 296 919,49 $ et le bénéfice total de 286 409,08 $.

À retenir : Furniture fait le deuxième chiffre d'affaires mais seulement 2,5 % de marge, et la région Central a la marge la plus faible.

### 5. Dashboard Power BI

Le dashboard se connecte à Snowflake (connecteur natif) et n'utilise que les trois tables de `GOLD` :

- deux cartes, pour le chiffre d'affaires total et le bénéfice total ;
- un histogramme des ventes par région ;
- un histogramme des ventes par catégorie ;
- une courbe de l'évolution mensuelle du chiffre d'affaires et du bénéfice.

Les captures sont dans `captures/`.

## Captures d'écran

| Fichier | Contenu |
| --- | --- |
| `captures/01_tests_dbt.png` | `dbt test` sur Snowflake : 16 tests, `PASS=16 WARN=0 ERROR=0` |
| `captures/02_schemas_snowflake.png` | Base `SUPERSTORE_DB` et ses schémas `RAW`, `SILVER`, `GOLD` |
| `captures/03_tables_gold.png` | Les 3 tables agrégées du schéma `GOLD` |
| `captures/04_table_raw_sales.png` | `RAW.SALES` : 9 994 lignes, colonnes du CSV en texte |
| `captures/05_table_silver_curation_sales.png` | `SILVER.CURATION_SALES` : 9 993 lignes, colonnes en snake_case typées |

## Reproduire le projet

Prérequis : Python 3.10 ou plus récent, et un compte Snowflake avec le rôle `SYSADMIN`.

```bash
python -m venv .venv
source .venv/bin/activate
pip install dbt-core dbt-snowflake
```

Connexion par paire de clés (aucun mot de passe dans les fichiers) :

1. générer une clé privée `~/.snowflake/superstore_rsa_key.p8` et la clé publique associée ;
2. dans Snowsight, enregistrer la clé publique : `ALTER USER <utilisateur> SET RSA_PUBLIC_KEY = '<clé publique>';` ;
3. copier `superstore_dbt/profiles.yml.example` dans `~/.dbt/profiles.yml`, puis renseigner le compte et l'utilisateur.

Exécution :

```bash
python snowflake/charger_raw.py        # RAW
cd superstore_dbt
dbt debug                               # vérifie la connexion
dbt build                               # SILVER, GOLD et les 16 tests
```
