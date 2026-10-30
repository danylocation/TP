{#- Utilise le schema configure (SILVER, GOLD) tel quel, au lieu du
    comportement par defaut de dbt qui le prefixe par le schema de la cible. -#}
{% macro generate_schema_name(custom_schema_name, node) -%}
    {%- if custom_schema_name is none -%}
        {{ target.schema }}
    {%- else -%}
        {{ custom_schema_name | trim | upper }}
    {%- endif -%}
{%- endmacro %}
