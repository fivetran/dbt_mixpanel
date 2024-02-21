{% macro mixpanel_lookback(from_date, datepart, interval, safety_date='2010-01-01') %}

{{ adapter.dispatch('mixpanel_lookback', 'mixpanel') (from_date, datepart, interval, safety_date='2010-01-01') }}

{%- endmacro %}

{% macro default__mixpanel_lookback(from_date, datepart, interval, safety_date='2010-01-01')  %}

    coalesce(
        (select {{ dbt.dateadd(datepart=datepart, interval=-interval, from_date_or_timestamp=from_date) }} 
            from {{ this }}), 
        {{ "'" ~ safety_date ~ "'" }}
        )

{% endmacro %}

{% macro bigquery__fivetran_log_lookback(from_date, datepart, interval, safety_date='2010-01-01')  %}

    -- Capture the latest timestamp in a call statement instead of a subquery for optimizing BQ costs on incremental runs
    {%- call statement('date_agg', fetch_result=True) -%}
        select cast({{ from_date }} as {{ casting }}) from {{ this }}
    {%- endcall -%}

    -- load the result from the above query into a new variable
    {%- set query_result = load_result('date_agg') -%}

    -- the query_result is stored as a dataframe. Therefore, we want to now store it as a singular value.
    {%- set date_agg = query_result['data'][0][0] %}

    coalesce(
        {{ dbt.dateadd(datepart=datepart, interval=-interval, from_date_or_timestamp="'" ~ date_agg ~ "'") }}, 
        {{ "'" ~ safety_date ~ "'" }}
        )

{% endmacro %}