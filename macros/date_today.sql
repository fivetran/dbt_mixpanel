{% macro date_today(col_name) %}

{{ adapter.dispatch('date_today', 'mixpanel') (col_name) }}

{% endmacro %}

{% macro default__date_today(col_name)  %}

cast( {{ dbt.date_trunc('day', dbt.current_timestamp_backcompat()) }} as date) as {{ col_name }}

{% endmacro %}

{% macro sqlserver__date_today(col_name)  %}

cast( {{ dbt.date_trunc('day', dbt.current_timestamp()) }} as date) as {{ col_name }}

{% endmacro %}
