{#- Echoue pour toute ligne ou la colonne sort de l'intervalle [min_value, max_value]. -#}
{% test value_between(model, column_name, min_value, max_value) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} is null
   or {{ column_name }} < {{ min_value }}
   or {{ column_name }} > {{ max_value }}

{% endtest %}
