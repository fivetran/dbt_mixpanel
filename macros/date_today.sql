{% macro date_today(col_name) %}

cast( {{ dbt.date_trunc('day', dbt.current_timestamp_backcompat()) }} as date) as {{ col_name }}
{# cast( '2024-02-06' as date) as {{ col_name }} -- for testing #}

{% endmacro %}