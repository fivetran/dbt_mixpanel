{{
    config(
        materialized='incremental',
        unique_key='session_id',
        partition_by={
            "field": "session_started_on_day",
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

        {% if var('session_passthrough_columns', []) != [] %}
        ,
        {{ var('session_passthrough_columns', [] ) | join(', ') }}
        {% endif %}

    from {{ ref('mixpanel__event') }}

    -- remove any events, etc
    where {{ var('session_event_criteria', 'true') }} 

    {% if is_incremental() %}

    -- grab ALL events for each user to appropriately use window functions to sessionize
    and device_id in (

        select distinct device_id
        from {{ ref('mixpanel__event') }}

        -- events can come in late and we want to still be able to incorporate them
        -- in the sessionization without requiring a full refresh
        where occurred_at >= cast (coalesce((
          select
            {{ dbt_utils.dateadd(
                'hour',
                -var('sessionization_trailing_window', 3),
                'max(session_started_at)'
            ) }}
          from {{ this }} ), '2010-01-01') as {{ dbt_utils.type_timestamp() }} )
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
        -- had the previous session timed out?
        case when {{ dbt_utils.datediff('previous_event_at', 'occurred_at', 'minute') }} > {{ var('sessionization_inactivity', 30) }} or previous_event_at is null then 1
        else 0 end as is_new_session

    from previous_event
),

session_numbers as (

    select *,

    -- will cumulatively create session numbers
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

        count(unique_event_id) over (partition by device_id, session_number, event_type order by occurred_at rows between unbounded preceding and unbounded following) as number_of_this_event_type,
        count(unique_event_id) over (partition by device_id, session_number order by occurred_at rows between unbounded preceding and unbounded following) as total_number_of_events


    from session_numbers

),

agg_event_types as (

    select 
        session_id,
        -- turn into json
        '{' || {{ fivetran_utils.string_agg("(event_type || ': ' || number_of_events)", "', '") }} || '}' as event_frequencies
    
    from (

        select
            session_id,
            event_type,
            count(unique_event_id) as number_of_events

        from session_ids
        group by session_id, event_type
    
    ) group by session_id
), 

session_join as (

    select 
        session_ids.session_id,
        session_ids.people_id,
        session_ids.session_started_at,
        session_ids.session_started_on_day,
        session_ids.device_id,
        session_ids.total_number_of_events,
        agg_event_types.event_frequencies

        {% if var('session_passthrough_columns', []) != [] %}
        ,
        {{ var('session_passthrough_columns', [] )  | join(', ') }}
        {% endif %}
    
    from session_ids
    join agg_event_types using(session_id) -- join regardless of event type

    where session_ids.is_new_session = 1 -- only return fields of first event

)

select * from session_join
