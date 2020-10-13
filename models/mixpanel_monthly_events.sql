{{
    config(
        materialized='incremental',
        unique_key='unique_key',
        partition_by={
            "field": "date_month",
            "data_type": "date"
        }
    )
}}

with events as (

    select 
        event_type,
        occurred_at,
        unique_event_id,
        people_id

    from {{ ref('mixpanel_event') }}

    where {{ var('timeline_criteria', 'true') }} 

    {% if is_incremental() %}

    -- look backward one month for churn/retention
    and occurred_at >= coalesce( (select cast ( 
                        {{ dbt_utils.dateadd(datepart='month', interval=-1, from_date_or_timestamp="max(date_month)") }} as {{ dbt_utils.type_timestamp() }} ) 
                        from {{ this }} ) ,'2000-01-01')

    {% endif %}
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
            cast({{ dbt_utils.date_trunc('month', 'events.occurred_at') }} as date) as date_month,
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

        -- defining repeat user as someone who also performed this action the previous month
        count(distinct case when previous_month_with_event is not null and 
            {{ dbt_utils.datediff('previous_month_with_event', 'date_month', 'month') }} = 1
            then people_id end) as number_of_repeat_users,

        -- defining return user as someone who has performed this action farther in the past
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
        lag(number_of_users, 1) over(partition by event_type order by date_month asc) - number_of_repeat_users as number_of_churn_users,

        date_month || '-' || event_type as unique_key -- for incremental model :)

    from monthly_metrics

    {% if is_incremental() %}

    -- only return the most recent month
    where date_month >= coalesce((select max(date_month) from {{ this }}), '2000-01-01')

    {% endif %}
)

select * from final