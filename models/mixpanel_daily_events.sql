{{
    config(
        materialized='incremental',
        unique_key='unique_key',
        partition_by={
            "field": "date_day",
            "data_type": "timestamp"
        }
    )
}}

with events as (

    select 
        event_type,
        occurred_at,
        people_id,
        unique_event_id,
        date_day

    from {{ ref('mixpanel_event') }}

    -- exclude events and/or apply filters to all/individual events
    where {{ var('timeline_criteria', 'true') }}

), 

calendar_spine as (
    
    select *
    from {{ ref('stg_user_event_date_spine') }}

    -- todo: incremental logic
    {% if is_incremental() %}
    and date_day >= (select {{ dbt_utils.dateadd(datepart='day', interval=-27, from_date_or_timestamp="max(date_day)") }}  from {{ this }} )

    {% endif %}
    
), 

user_aggregated as (
    
    select
        cast(occurred_at as date) as date_day
        people_id,
        event_type,
        count(*) as count_events
    from events
    group by 1,2,3
    
), 

calendar_joined as (
    
    select
        calendar_spine.date_day,
        calendar_spine.people_id,
        calendar_spine.event_type
        coalesce(user_aggregated.count_events,0) as count_events
    from calendar_spine
    left join user_aggregated
        using (date_day, people_id, event_type)

), 

window_functions as (
    
    select
        *,
        sum(count_events) over (partition by people_id, event_type order by date_day asc rows between 27 preceding and current row) > 0 as event_in_last_28_days,
        sum(count_events) over (partition by people_id, event_type order by date_day asc rows between 6 preceding and current row) > 0 as event_in_last_7_days
    from calendar_joined
    
), 

day_aggregated as (
    
    select
        date_day,
        event_type,
        sum(case when count_events > 0 then 1 end) as number_of_users,
        sum(count_events) as number_of_events,
        sum(case when event_in_last_28_days = True then 1 end) as trailing_users_28d,
        sum(case when event_in_last_7_days = True then 1 end) as trailing_users_7d
    from window_funtions
    group by 1,2
    
)

select *
from day_aggregated
