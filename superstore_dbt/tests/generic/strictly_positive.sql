{#- Echoue pour toute ligne ou la colonne est nulle, nulle ou negative. -#}
{% test strictly_positive(model, column_name) %}

select {{ column_name }}
from {{ model }}
where {{ column_name }} is null
   or {{ column_name }} <= 0

{% endtest %}
