{{
    config(
        materialized='incremental' if mixpanel.is_incremental_compatible() else 'table',
        unique_key='unique_key',
        incremental_strategy='insert_overwrite' if target.type in ('bigquery', 'spark', 'databricks') else 'delete+insert',
        partition_by={
            "field": "date_month", 
            "data_type": "date"
            } if target.type not in ('spark', 'databricks', 'duckdb') 
            else ['date_month'],
        cluster_by=['date_month', 'event_type', 'source_relation'],
        file_format='delta'
    )
}}

with events as (

    select 
        source_relation,
        event_type,
        occurred_at,
        unique_event_id,
        people_id,
        cast( {{ dbt.date_trunc('month', 'occurred_at') }} as date) as date_month

    from {{ ref('mixpanel__event') }}

    {% if is_incremental() %}
    where date_day >= {{ mixpanel.mixpanel_lookback(from_date="max(date_month)", datepart='month', interval=1) }}
    {% endif %}
),

{% if is_incremental() %}
prior_user_months as (

    select
        source_relation,
        people_id,
        event_type,
        max(cast( {{ dbt.date_trunc('month', 'occurred_at') }} as date)) as last_month_with_event

    from {{ ref('mixpanel__event') }}
    where date_day < {{ mixpanel.mixpanel_lookback(from_date="max(date_month)", datepart='month', interval=1) }}
    group by 1,2,3
),

prior_monthly_users as (

    select
        source_relation,
        event_type,
        number_of_users
    from (
        select
            source_relation,
            event_type,
            number_of_users,
            row_number() over(partition by event_type {{ fivetran_utils.partition_by_source_relation(package_name='mixpanel') }} order by date_month desc) as month_rank
        from {{ this }}
        where date_month < {{ mixpanel.mixpanel_lookback(from_date="max(date_month)", datepart='month', interval=1) }}
    ) as ranked_months
    where month_rank = 1
),
{% endif %}

user_first_events as (

    select
        source_relation,
        people_id,
        event_type,
        cast( {{ dbt.date_trunc('month', 'first_event_day') }} as date) as first_month
    from {{ ref('stg_mixpanel__user_first_event') }}
),

month_totals as (
    
    select 
        source_relation,
        date_month,
        count(distinct people_id) as total_monthly_active_users
    from events
    group by 1,2
),

sub as (
-- aggregate number of events to the month
        select
            source_relation,
            people_id,
            event_type,
            date_month,
            count(unique_event_id) as number_of_events

        from events
        {{ dbt_utils.group_by(n=4) }}
), 

user_monthly_events as (

    select 
        sub.*,
        -- first time a user did this kind of event
        user_first_events.first_month,

        -- last month that the user performed this kind of event during
        {% if is_incremental() -%}
        coalesce(
            lag(sub.date_month, 1) over(partition by sub.people_id, sub.event_type {{ fivetran_utils.partition_by_source_relation(package_name='mixpanel', alias='sub') }} order by sub.date_month asc),
            prior_user_months.last_month_with_event
        ) as previous_month_with_event
        {%- else -%}
        lag(sub.date_month, 1) over(partition by sub.people_id, sub.event_type {{ fivetran_utils.partition_by_source_relation(package_name='mixpanel', alias='sub') }} order by sub.date_month asc) as previous_month_with_event
        {%- endif %}

    from sub
    left join user_first_events
        on sub.people_id = user_first_events.people_id
        and sub.event_type = user_first_events.event_type
        and sub.source_relation = user_first_events.source_relation
    {% if is_incremental() -%}
    left join prior_user_months
        on sub.people_id = prior_user_months.people_id
        and sub.event_type = prior_user_months.event_type
        and sub.source_relation = prior_user_months.source_relation
    {%- endif %}
),

monthly_metrics as (

    select 
        user_monthly_events.source_relation,
        user_monthly_events.date_month,
        user_monthly_events.event_type,
        month_totals.total_monthly_active_users,

        count(distinct user_monthly_events.people_id) as number_of_users,
        count( distinct case when user_monthly_events.first_month = user_monthly_events.date_month then user_monthly_events.people_id end) as number_of_new_users,

        -- defining repeat user as someone who also performed this action the previous month
        count(distinct case when user_monthly_events.previous_month_with_event is not null and 
            {{ dbt.datediff('user_monthly_events.previous_month_with_event', 'user_monthly_events.date_month', 'month') }} = 1
            then user_monthly_events.people_id end) as number_of_repeat_users,

        -- defining return user as someone who has performed this action farther in the past
        count(distinct case when user_monthly_events.previous_month_with_event is not null and
            {{ dbt.datediff('user_monthly_events.previous_month_with_event', 'user_monthly_events.date_month', 'month') }} > 1
            then user_monthly_events.people_id end) as number_of_return_users,

        sum(user_monthly_events.number_of_events) as number_of_events

    from user_monthly_events
        left join month_totals 
            on user_monthly_events.source_relation = month_totals.source_relation
            and user_monthly_events.date_month = month_totals.date_month
    {{ dbt_utils.group_by(n=4) }}
),

-- add churn!
final as (

    select
        monthly_metrics.*,

        -- subtract the returned users from the previous month's total users to get the # churned
        -- note: churned users refer to users who did something last month and not this month
        {% if is_incremental() -%}
        coalesce(coalesce(lag(monthly_metrics.number_of_users, 1) over(partition by monthly_metrics.event_type {{ fivetran_utils.partition_by_source_relation(package_name='mixpanel', alias='monthly_metrics') }} order by monthly_metrics.date_month asc), prior_monthly_users.number_of_users) - monthly_metrics.number_of_repeat_users, 0) as number_of_churn_users,
        {%- else -%}
        coalesce(lag(monthly_metrics.number_of_users, 1) over(partition by monthly_metrics.event_type {{ fivetran_utils.partition_by_source_relation(package_name='mixpanel', alias='monthly_metrics') }} order by monthly_metrics.date_month asc) - monthly_metrics.number_of_repeat_users, 0) as number_of_churn_users,
        {%- endif %}
        monthly_metrics.date_month || '-' || monthly_metrics.event_type || '-' || monthly_metrics.source_relation as unique_key, -- for incremental model :)
        current_date as dbt_run_date

    from monthly_metrics
    {% if is_incremental() -%}
    left join prior_monthly_users
        on monthly_metrics.event_type = prior_monthly_users.event_type
        and monthly_metrics.source_relation = prior_monthly_users.source_relation
    {%- endif %}
)

select * from final