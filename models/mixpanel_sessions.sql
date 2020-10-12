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

        -- todo: test with passthrough columns for first event
        {% if var('session_passthrough_columns', []) != [] %}
        ,
        {{ var('session_passthrough_columns', [] ) | join(', ') }}
        {% endif %}

    from {{ ref('mixpanel_event') }}

    where {{ var('session_criteria', 'true') }} 

    {% if is_incremental() %}
    and device_id in (

        select distinct device_id
        from {{ ref('mixpanel_event') }}

        where occurred_at >= coalesce((
          select
            {{ dbt_utils.dateadd(
                'hour',
                -var('sessionization_trailing_window', 3),
                'max(started_at)'
            ) }}
          from {{ this }} ), '2000-01-01')
    )

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
        min(occurred_at) over (partition by device_id, session_number) as session_started_at,
        min(date_day) over (partition by device_id, session_number) as session_started_on_day,
        {{ dbt_utils.surrogate_key(['device_id', 'session_number']) }} as session_id,
        count(unique_event_id) over(partition by device_id, session_number, event_type) as number_of_event_type,


    from session_numbers

),

agg_events as (

    select
        session_id,
        event_type,
        people_id,
        session_started_at,
        session_started_on_day,
        device_id,
        count(unique_event_id) as number_of_events
        -- todo: add passthrough columns after testing 


    from 
    session_ids

    group by 1,2,3,4,5,6
),

agg_event_types as (

    select 
        session_id,
        people_id,
        session_started_at,
        session_started_on_day,
        device_id,
        {{ fivetran_utils.string_agg('event_type || ": " || number_of_events', ) }} as event_frequencies,
        sum(number_of_events) as total_number_of_events,

)

-- first event fields, last event id
-- string_agg of frequency of event types, 

select * from session_ids
