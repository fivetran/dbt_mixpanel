{{
    config(
        materialized='incremental',
        unique_key='unique_event_id',
        partition_by={
            "field": "date_day",
            "data_type": "timestamp"
        }
    )
}}

with stg_event as (

    select *

    from {{ ref('stg_mixpanel_event') }}

    {% if is_incremental() %}

    -- events are only eligible for de-duping if they occurred on the same calendar day 
    where occurred_at >= (select max(date_day) from {{ this }} )
    {% endif %}
),

--  todo: bump drew on timezone question
dedupe as (

    select * from (

    select 
        *,
        -- aligned with mixpanel' s deduplication method: https://developer.mixpanel.com/reference/http#event-deduplication
        -- really de-duping on calendar day + insert_id (concatenated = unique_event_id), but also partitioning on people_id + event_type to reduce the rate of false positives 
        row_number() over(partition by unique_event_id, people_id, event_type order by mp_processing_time_ms asc) as nth_event_record
        
        from stg_event
    ) 
    where nth_event_record = 1

),

pivot_properties as (
    select *,
    {{ pivot_event_properties_json(var('event_properties_to_pivot', [])) }}
    
    from dedupe

)

select * from pivot_properties