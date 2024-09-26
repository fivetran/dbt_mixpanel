{{ config(materialized='view') }}

-- using source to look at ALL-TIME events
-- mixpanel__event is cut off by the `date_range_start` variable
with first_events as (

    select 
        people_id,
        source_relation,
        event_type,
        min(date_day) as first_event_day
    
    from {{ ref('stg_mixpanel__event') }}
    group by 1,2

)

select * 
from first_events