{{
    config(
        materialized='incremental',
        unique_key='unique_key',
        partition_by={
            "field": "date_day",
            "data_type": "date"
        }
    )
}}

with user_first_events as (

    select * 
    from {{ ref('stg_user_first_event') }}
),

spine as (

    select * 
    from (
        {{ dbt_utils.date_spine(
            datepart = "day", 
            start_date =  "'" ~ var('date_range_start',  '2010-01-01') ~ "'" , 
            end_date = dbt_utils.dateadd("week", 1, dbt_utils.date_trunc('day', dbt_utils.current_timestamp())) 
            ) 
        }} 
    )

    {% if is_incremental %} 
    where date_day > ( select max(date_day) from {{ this }} )
    {% endif %}
    
),

user_event_spine as (

    select
        spine.date_day,
        user_first_events.people_id,
        user_first_events.event_type,
        user_first_events.people_id || '-' || spine.date_day as unique_key

    from
    spine join user_first_events  -- can't do left join with >= 
        on spine.date_day >= user_first_events.first_event_day

    group by 1,2,3
    
)

select * from user_event_spine
