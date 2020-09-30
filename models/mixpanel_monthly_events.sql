-- probably want to config this as incremental 

with events as (

    select 
        event_type,
        occurred_at,
        unique_event_id,
        people_id

    from {{ ref('mixpanel_event') }}

    where {{ var('timeline_criteria', 'true') }} 
),

user_monthly_events as (

    select 
        *, 
        -- add window functions
        min(date_month) over(partition by people_id, event_type) as first_month,
        lag(date_month, 1) over(partition by people_id, event_type order by date_month asc) previous_month_with_event,
        count(distinct people_id) over( partition by date_month ) as total_monthly_active_users

    from (
        -- use aggregate functions
        select
            people_id,
            event_type,
            {{ dbt_utils.date_trunc('month', 'events.occurred_at') }} as date_month,
            count(unique_event_id) as number_of_events

        from events
        group by 1,2,3
    )
),

monthly_metrics as (

    select 
        date_month,
        event_type,
        total_monthly_active_users,
        count(distinct people_id) as number_of_users,
        count( distinct case when first_month = date_month then people_id end) as number_of_new_users,

        count(distinct case when previous_month_with_event is not null and 
            {{ dbt_utils.datediff('previous_month_with_event', 'date_month', 'month') }} = 1
            then people_id end) as number_of_repeat_users,

        count(distinct case when previous_month_with_event is not null and
            {{ dbt_utils.datediff('previous_month_with_event', 'date_month', 'month') }} > 1
            then people_id end) as number_of_return_users,

        sum(number_of_events) as number_of_events
        


    from user_monthly_events
    group by 1,2,3
),

-- add churn!
final as (

    select
        *,
        -- subtract the returned users from the previous month's total users to get the # churned
        -- note: churned users refer to users who did something last month and not this month
        lag(number_of_users, 1) over(partition by event_type order by date_month asc) - number_of_repeat_users as number_of_churn_users

    from monthly_metrics
)

select * from final