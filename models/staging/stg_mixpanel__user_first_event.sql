{{
    config(
        materialized='table'
    )
}}

-- using source to look at ALL-TIME events
-- stg_mixpanel__event is cut off by the `date_range_start` variable
with first_events as (

    select 
        distinct_id as people_id,
        lower(name) as event_type,
        cast(min(time) as date) as first_event_day
    
    from {{ var('event_table') }}
    group by 1, 2
)

select * from first_events