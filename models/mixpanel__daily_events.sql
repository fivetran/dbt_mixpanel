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
        cluster_by=['date_day', 'event_type'],
        file_format='parquet'
    )
}}

with events as (

    select 
        event_type,
        occurred_at,
        people_id,
        unique_event_id,
        date_day

    from {{ ref('mixpanel__event') }}

    {% if is_incremental() %}

    -- we look at the most recent 28 days for this model's window functions to compute properly
    where date_day >= coalesce( ( select {{ dbt.dateadd(datepart='day', interval=-27, from_date_or_timestamp="max(date_day)") }}  
                                from {{ this }} ), '2010-01-01')

    {% endif %}

),


date_spine as (
    
    select *
    from {{ ref('stg_mixpanel__user_event_date_spine') }}

    {% if is_incremental() %}

    -- look backward for the last 28 days
    where date_day >= coalesce((select {{ dbt.dateadd(datepart='day', interval=-27, from_date_or_timestamp="max(date_day)") }}  
                                from {{ this }} ), '2010-01-01')

    {% endif %}
), 

agg_user_events as (
    
    select
        date_day,
        people_id,
        event_type,
        count(unique_event_id) as number_of_events

    from events
    group by 1,2,3
), 

-- join the spine with event metrics
spine_joined as (
    
    select
        date_spine.date_day,
        date_spine.people_id,
        date_spine.event_type,
        date_spine.is_first_event_day,
        coalesce(agg_user_events.number_of_events, 0) as number_of_events
        
    from date_spine

    left join agg_user_events
        on agg_user_events.date_day = date_spine.date_day
        and agg_user_events.people_id = date_spine.people_id
        and agg_user_events.event_type = date_spine.event_type
), 

trailing_events as (
    
    select
        *,
        sum(number_of_events) over (partition by people_id, event_type order by date_day asc rows between 27 preceding and current row) > 0 as has_event_in_last_28_days,
        sum(number_of_events) over (partition by people_id, event_type order by date_day asc rows between 6 preceding and current row) > 0 as has_event_in_last_7_days,

        -- defining a repeat user as someone who performed an action on a given day after previously having done so in the last 28 days
        sum(number_of_events) over (partition by people_id, event_type order by date_day asc rows between 27 preceding and 1 preceding) > 0 
            and number_of_events > 0 as is_repeat_user

    from spine_joined
), 

agg_event_days as (
    
    select
        date_day,
        event_type,
        sum(number_of_events) as number_of_events,
        sum(case when number_of_events > 0 then 1 else 0 end) as number_of_users,

        -- is_first_event_day is not subject to the timeline criteria
        sum(case when number_of_events > 0 then is_first_event_day else 0 end) as number_of_new_users, 
        sum(case when is_repeat_user = true then 1 else 0 end) as number_of_repeat_users,
        
        sum(case when has_event_in_last_28_days = True then 1 else 0 end) as trailing_users_28d,
        sum(case when has_event_in_last_7_days = True then 1 else 0 end) as trailing_users_7d

    from trailing_events
    group by 1,2
),

final as (

    select 

        date_day,
        event_type,
        number_of_events,
        number_of_users,
        number_of_new_users,
        number_of_repeat_users,

        -- "return user" is someone who has done an action on a given day after not doing so for the past 28 days
        number_of_users - number_of_new_users - number_of_repeat_users as number_of_return_users,
        trailing_users_28d,
        trailing_users_7d,
        {{ dbt_utils.generate_surrogate_key(['event_type', 'date_day']) }} as unique_key

    from agg_event_days
)

select *
from final