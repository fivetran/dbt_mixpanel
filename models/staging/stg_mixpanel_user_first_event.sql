{{
    config(
        materialized='table'
    )
}}

-- using stg_mixpanel_event to look at ALL-TIME events
-- mixpanel_event is cut off by the `date_range_start` variable
with alltime_events as (

    select *
    from {{ ref('stg_mixpanel_event') }}
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