{{
    config(
        materialized='incremental' if mixpanel.is_incremental_compatible() else 'table',
        unique_key='unique_key',
        incremental_strategy='insert_overwrite' if target.type in ('bigquery', 'spark', 'databricks') else 'delete+insert',
        partition_by={
            "field": "date_day", 
            "data_type": "date"
            } if target.type not in ('spark','databricks') 
            else ['date_day'],
        cluster_by=['date_day', 'event_type', 'people_id', 'source_relation'],
        file_format='delta'
    )
}}

with user_first_events as (

    select * 
    from {{ ref('stg_mixpanel__user_first_event') }}
),

spine as (
    {% if execute and flags.WHICH in ('run', 'build') %}
        {% if is_incremental() %}
            -- For incremental runs, the first_date is 14 days prior to the max date since we need to
            -- account for the week that is added to the end_date.
            {%- set first_date_query %}
                select 
                    cast({{ mixpanel.mixpanel_lookback(from_date="max(date_day)", interval=14, datepart='day') }} as date)
            {% endset -%}
            {%- set first_date = dbt_utils.get_single_value(first_date_query) %}

        {% else %}
            -- For full-refresh runs, use either the date from var(date_range_start) or the min date.
            {%- set first_date_query %}
                select 
                    coalesce(
                        min(cast(first_event_day as date)), 
                        cast({{ dbt.dateadd("month", -1, "current_date") }} as date)
                        ) as min_date
                from {{ ref('stg_mixpanel__user_first_event') }}
            {% endset -%}
            {%- set first_date = var('date_range_start', dbt_utils.get_single_value(first_date_query)) %}
        {% endif %}

    {% else %}
        {%- set first_date_query %}
            select
                cast({{ dbt.dateadd("month", -1, "current_date") }} as date)
        {% endset -%}
        {%- set first_date = dbt_utils.get_single_value(first_date_query) %}
    {% endif %}

    -- Every user-event_type shares the same final date.
    {{ dbt_utils.date_spine(
        datepart = "day", 
        start_date =  "cast('" ~ first_date ~ "' as date)", 
        end_date = dbt.dateadd("week", 1, "current_date") 
        ) 
    }} 
),

user_event_spine as (

    select
        user_first_events.source_relation,
        cast(spine.date_day as date) as date_day,
        user_first_events.people_id,
        user_first_events.event_type,

        -- will use this in mixpanel__daily_events
        case when spine.date_day = user_first_events.first_event_day then 1 else 0 end as is_first_event_day,

        {{ dbt_utils.generate_surrogate_key(['user_first_events.people_id', 'spine.date_day', 'user_first_events.event_type', 'user_first_events.source_relation']) }} as unique_key

    from spine
    join user_first_events
        on spine.date_day >= user_first_events.first_event_day -- each user-event_type will a record for every day since their first day
    {{ dbt_utils.group_by(n=6) }}
    
)

select *
from user_event_spine