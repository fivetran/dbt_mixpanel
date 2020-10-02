-- probably want to config this as incremental 

with events as (

    select 
        event_type,
        date_day,
        people_id,
        unique_event_id

    from {{ ref('mixpanel_event') }}

    -- exclude events and/or apply filters to all/individual events
    where {{ var('timeline_criteria', 'true') }}
),

user_metrics as (

    select 
        *,
        min(date_day) over(partition by people_id, event_type) as first_day,
        lag(date_day, 1) over(partition by people_id, event_type order by date_day asc) previous_day_with_event,
        count(distinct people_id) over( partition by date_day ) as total_daily_active_users,
        {# dense_rank() over(partition by event_type order by people_id rows between 27 preceding and current row) as nth_unique_user_28d,
        dense_rank() over(partition by event_type order by people_id rows between 6 preceding and current row) as nth_unique_user_7d       #}

        -- can't do this because it assumes that people are doing this every day
        count(date_day) over(partition by people_id, event_type order by date_day asc rows between 27 preceding and 1 preceding) as previous_active_days_28d,
        count(date_day) over(partition by people_id, event_type order by date_day asc rows between 6 preceding and 1 preceding) as previous_active_days_7d

 

    from (
        select
            people_id,
            event_type,
            date_day,
            count(unique_event_id) as number_of_events

        from events
        group by 1,2,3
    )
),

event_metrics as (

    select
        date_day,
        event_type,
        total_daily_active_users,
        sum(number_of_events) as number_of_events,
        -- count(distinct events.unique_event_id) as number_of_events,
        count(distinct people_id) as number_of_users, 

        count( distinct case when date_day = first_day then people_id end) as number_of_new_users,

        count(distinct case when previous_day_with_event is not null and 
            {{ dbt_utils.datediff('previous_day_with_event', 'date_day', 'day') }} <= 27
            then people_id end) as number_of_repeat_users,

        count(distinct case when previous_day_with_event is not null and 
            {{ dbt_utils.datediff('previous_day_with_event', 'date_day', 'day') }} > 27
            then people_id end) as number_of_return_users,

        {# count(distinct case when past_month.people_id = events.people_id and 
            {{ dbt_utils.date_trunc('day', 'past_month.occurred_at') }} < {{ dbt_utils.date_trunc('day', 'events.occurred_at') }}
            then events.people_id end) as number_of_repeat_users,  #}
{# 
        max(nth_unique_user_28d) as trailing_users_28d,
        max(nth_unique_user_7d) as trailing_users_7d #}
        

        count(people_id) over (partition by event_type order by date_day asc range between 6 preceding and current row) as trailing_users_7d,
        count(people_id) over (partition by event_type order by date_day asc range between 27 preceding and current row) as trailing_users_28d
        {# count(distinct past_month.people_id) as trailing_users_28d,
        count(distinct case when {{ dbt_utils.datediff('past_month.occurred_at', 'events.occurred_at', 'day') }} <= 6 then past_month.people_id end) as trailing_users_7d #}
        
    {# from events  #}
    -- todo: can we use a window function instead of a self join? see monthly events
    {# join events  #}
    {# past_month 
        on events.event_type = past_month.event_type
        and {{ dbt_utils.datediff('past_month.occurred_at', 'events.occurred_at', 'day') }} <= 27 #}

    from user_metrics 
        {# on user_metrics.people_id = events.people_id
        and user_metrics.event_type = events.event_type #}

    group by 1,2,3
),

final as (

    select
        date_day,
        event_type,
        number_of_events,
        number_of_users,
        number_of_new_users,
        number_of_repeat_users,
        number_of_return_users,
        
        -- users who are not new and not repeat must be resurrected from earlier
        (number_of_users - number_of_new_users - number_of_repeat_users) as number_of_return_users_minus,
        trailing_users_28d,
        trailing_users_7d

    from event_metrics
    order by date_day desc, event_type

)

select * from final