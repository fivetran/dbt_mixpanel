{{
    config(
        materialized='table'
    )
}}

-- looking at events before we cut them off with a date range
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