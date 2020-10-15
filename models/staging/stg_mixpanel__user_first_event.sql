{{
    config(
        materialized='table'
    )
}}

-- using stg_mixpanel__event to look at ALL-TIME events
-- mixpanel__event is cut off by the `date_range_start` variable
with alltime_events as (

    select *
    from {{ ref('stg_mixpanel__event') }}

),

first_events as (

    select 
        people_id,
        event_type,
        min(date_day) as first_event_day
    
    from alltime_events

    group by people_id, event_type
)

select * from first_events