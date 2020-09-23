-- probably want to config this as incremental 

with events as (

    select 
        event_type,
        occurred_at,
        people_id,
        unique_event_id

    from {{ ref('mixpanel_event') }}

    where {{ var('daily_event_criteria', true) }}
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
        {{ dbt_utils.date_trunc('day', 'events.occurred_at') }} as date_day,
        events.event_type,

        count(distinct events.unique_event_id) as number_of_events,
        count(distinct events.people_id) as number_of_users, 

        count( distinct case when {{ dbt_utils.date_trunc('day', 'events.occurred_at') }} = {{ dbt_utils.date_trunc('day', 'user_metrics.first_event_at') }} 
            then events.people_id end) as number_of_new_users,

        count(distinct case when past_month.people_id = events.people_id and 
            {{ dbt_utils.date_trunc('day', 'past_month.occurred_at') }} < {{ dbt_utils.date_trunc('day', 'events.occurred_at') }}
            then events.people_id end) as number_of_repeat_users, 

        count(distinct past_month.people_id) as trailing_users_28d,
        count(distinct case when {{ dbt_utils.datediff('past_month.occurred_at', 'events.occurred_at', 'day') }} <= 7 then past_month.people_id end) as trailing_users_7d
        
    from events 
    -- todo: can we use a window function instead of a self join?
    join events past_month 
        on events.event_type = past_month.event_type
        and {{ dbt_utils.datediff('past_month.occurred_at', 'events.occurred_at', 'day') }} <= 28

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
        
        -- doing it this way to avoid another self-join with big event data
        (number_of_users - number_of_new_users - number_of_repeat_users) as number_of_return_users,
        trailing_users_28d,
        trailing_users_7d

    from event_metrics
    order by date_day desc, event_type

)

select * from final