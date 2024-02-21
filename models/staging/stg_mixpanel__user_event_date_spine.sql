{{
    config(
        materialized='incremental',
        unique_key='unique_key',
        incremental_strategy='insert_overwrite' if target.type in ('bigquery', 'spark', 'databricks') else 'delete+insert',
        partition_by={
            "field": "date_day", 
            "data_type": "date"
            } if target.type not in ('spark','databricks') 
            else ['date_day'],
        cluster_by=['date_day', 'event_type', 'people_id'],
        file_format='parquet'
    )
}}

with user_first_events as (

    select * 
    from {{ ref('stg_mixpanel__user_first_event') }}
),

spine as (

    select *

    from (
        {{ dbt_utils.date_spine(
            datepart = "day", 
            start_date =  "cast('" ~ var('date_range_start',  '2010-01-01') ~ "' as date)", 
            end_date = dbt.dateadd("week", 1, dbt.date_trunc('day', dbt.current_timestamp_backcompat())) 
            ) 
        }} 
    ) as spine
    {% if is_incremental() %} 
    -- every user-event_type will have the same last day. Add 7 days to the lookback to account for the week added above.
    where date_day >= {{ mixpanel.mixpanel_lookback(from_date="max(date_day)", interval=var('lookback_window', 7) + 7, datepart='day') }}
    {% endif %}
),

user_event_spine as (

    select
        cast(spine.date_day as date) as date_day,
        user_first_events.people_id,
        user_first_events.event_type,

        -- will use this in mixpanel__daily_events
        case when spine.date_day = user_first_events.first_event_day then 1 else 0 end as is_first_event_day,

        {{ dbt_utils.generate_surrogate_key(['user_first_events.people_id', 'spine.date_day', 'user_first_events.event_type']) }} as unique_key

    from spine
    join user_first_events
        on spine.date_day >= user_first_events.first_event_day -- each user-event_type will a record for every day since their first day
    group by 1,2,3,4,5
    
)

select * from user_event_spine
