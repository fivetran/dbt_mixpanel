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

    {% if is_incremental() %}

    and occurred_at >= (select cast ( {{ dbt_utils.dateadd(datepart='day', interval=-27, from_date_or_timestamp="max(date_day)") }} as {{ dbt_utils.type_timestamp() }} ) from {{ this }} )

    {% endif %}
),

user_metrics as (

    select
        people_id,
        event_type,
        min(occurred_at) as first_event_at

    from events
    group by 1,2
),

event_metrics as (

    select
        events.date_day,
        events.event_type,

        count(distinct events.unique_event_id) as number_of_events,
        count(distinct events.people_id) as number_of_users, 

        count( distinct case when {{ dbt_utils.date_trunc('day', 'events.occurred_at') }} = {{ dbt_utils.date_trunc('day', 'user_metrics.first_event_at') }} 
            then events.people_id end) as number_of_new_users,

        count(distinct case when past_month.people_id = events.people_id and 
            {{ dbt_utils.date_trunc('day', 'past_month.occurred_at') }} < {{ dbt_utils.date_trunc('day', 'events.occurred_at') }} -- exclude same day
            then events.people_id end) as number_of_repeat_users, 

        count(distinct past_month.people_id) as trailing_users_28d,
        count(distinct case when {{ dbt_utils.datediff('past_month.occurred_at', 'events.occurred_at', 'day') }} <= 7 then past_month.people_id end) as trailing_users_7d
        
    from events 
    -- todo: can we use a window function instead of a self join? see monthly events
    -- subtract the number of users who have done this in the -7,-1 days. get this by doing a max window function at the user-date-event type level 
    -- in a window frame -7,-1 rows before the current day (partition by people_id, event_type order by date_day 6 rows preceding and 1 row precending)
    -- then check if that is in the past week/month
    -- then count(people_id) over(partition by event_type order by date_day asc 6 rows preceding and 1 row preceding) - sum(has_done_this_already)
    join events past_month 
        on events.event_type = past_month.event_type
        and {{ dbt_utils.datediff('past_month.occurred_at', 'events.occurred_at', 'day') }} <= 27

    join user_metrics 
        on user_metrics.people_id = events.people_id
        and user_metrics.event_type = events.event_type

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
        
        -- users who are not new and not repeat must be resurrected from earlier
        (number_of_users - number_of_new_users - number_of_repeat_users) as number_of_return_users,
        trailing_users_28d,
        trailing_users_7d,
        date_day || '-' || event_type as unique_key -- for incremental model :)

    from event_metrics

    {% if is_incremental() %}

    where date_day >= (select max(date_day) from {{ this }})

    {% endif %}

    order by date_day desc, event_type

)

select * from final