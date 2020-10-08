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

    {% if is_incremental() %}
    and date_day >= coalesce( (select {{ dbt_utils.dateadd(datepart='day', interval=-27, from_date_or_timestamp="max(date_day)") }}  from {{ this }} ), '2000-01-01')

    {% endif %}

), 

date_spine as (
    
    select *
    from {{ ref('stg_user_event_date_spine') }}

    -- todo: incremental logic
    {% if is_incremental() %}
    where date_day >= coalesce( (select {{ dbt_utils.dateadd(datepart='day', interval=-27, from_date_or_timestamp="max(date_day)") }}  from {{ this }} ), '2000-01-01')

    {% endif %}
    
), 

agg_user_events as (
    
    select
        date_day
        people_id,
        event_type,
        count(unique_event_id) as number_of_events
    from events
    group by 1,2,3
    
), 

spine_joined as (
    
    select
        date_spine.date_day,
        date_spine.people_id,
        date_spine.event_type,
        date_spine.is_first_event_day,
        coalesce(agg_user_events.number_of_events, 0) as number_of_events
        
    from date_spine

    left join agg_user_events
        using (date_day, people_id, event_type)

), 

trailing_events as (
    
    select
        *,
        sum(number_of_events) over (partition by people_id, event_type order by date_day asc rows between 27 preceding and current row) > 0 as had_event_in_last_28_days,
        sum(number_of_events) over (partition by people_id, event_type order by date_day asc rows between 6 preceding and current row) > 0 as had_event_in_last_7_days

    from spine_joined
    
), 

agg_event_days as (
    
    select
        date_day,
        event_type,
        sum(count_events) as number_of_events,
        count(distinct people_id) as number_of_users,
        sum(is_first_event_day) as number_of_new_users, 
        sum(case when had_event_in_last_28_days = false and number_of_events > 0 then 1 else 0 end) as number_of_repeat_users,
       -- sum(case when count_events > 0 then 1 end) as number_of_users,
        
        sum(case when event_in_last_28_days = True then 1 else 0 end) as trailing_users_28d,
        sum(case when event_in_last_7_days = True then 1 else 0 end) as trailing_users_7d

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
        number_of_users - number_of_new_users - number_of_repeat_users as number_of_return_users,
        trailing_users_28d,
        trailing_users_7d,
        event_type || '-' || date_day as unique_key

)

select *
from final
