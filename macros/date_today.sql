{% macro mixpanel_date_today(col_name) %}

{{ adapter.dispatch('mixpanel_date_today', 'mixpanel') (col_name) }}

{%- endmacro %}

{% macro default__mixpanel_date_today(col_name)  %}

cast( {{ dbt.date_trunc('day', dbt.current_timestamp_backcompat()) }} as date) as {{ col_name }}

{% endmacro %}

{% macro sqlserver__mixpanel_date_today(col_name)  %}

cast( {{ dbt.date_trunc('day', dbt.current_timestamp()) }} as date) as {{ col_name }}

{% endmacro %}