{{
    config(
        materialized='incremental',
        unique_key='session_key',
        partition_by={
            "field": "started_on_day",
            "data_type": "date"
        }
    )
}}

-- need to grab all events for relevant users
with events as (

    select 
        event_type,
        occurred_at,
        unique_event_id,
        people_id,
        date_day,
        device_id
        -- todo: any pass through columns?

    from {{ ref('mixpanel_event') }}

    where {{ var('session_criteria', 'true') }} 

    {% if is_incremental() %}
    and device_id in (

        select distinct device_id
        from {{ref('mixpanel_event')}}

        where occurred_at >= (
          select
            {{ dbt_utils.dateadd(
                'hour',
                -var('sessionization_trailing_window', 3),
                'max(started_at)'
            ) }}
          from {{ this }} )
    )
    -- create sessionization_trailing_window (default 6 hrs?)
    {# and occurred_at >= (
        select cast ( {{ dbt_utils.dateadd(datepart='hour', 
                                    interval=-var('sessionization_trailing_window', 6), 
                                    from_date_or_timestamp="max(started_at)") }} 

                    as {{ dbt_utils.type_timestamp() }} ) from {{ this }} 
        ) #}

    {% endif %}
),

previous_event as (

    select 
        *,
        lag(occurred_at) over(partition by device_id order by occurred_at asc) as previous_event_at

    from events 

),

new_sessions as (
    
    select 
        *,
        case when {{ dbt_utils.datediff('previous_event_at', 'occurred_at', 'minute') }} > {{ var('sessionization_inactivity', 30) }} then 1
        else 0 end as is_new_session

    from lagged_events
),

session_numbers as (

    select *,

    -- will cumulatively create session ids
    sum(is_new_session) over (
            partition by device_id
            order by occurred_at asc
            rows between unbounded preceding and current row
            ) as session_number

    from new_sessions
),

session_ids as (

    select
        *,
        {{ dbt_utils.surrogate_key(['device_id', 'session_number']) }} as session_id

    from session_numbers
)

select * from session_ids
