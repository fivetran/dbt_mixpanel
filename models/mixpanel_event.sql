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

    where 
    {% if is_incremental() %}

    -- events are only eligible for de-duping if they occurred on the same calendar day 
    where occurred_at >= (select cast( max(date_day) as {{ dbt_utils.type_timestamp() }} ) from {{ this }} )

    {% else %}
    
    -- limit date range on the first run / refresh
    where occurred_at >= {{ "'" ~ var('date_range_start',  '2010-01-01') ~ "'" }} 
    
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

    select 
        *,
        {{ pivot_event_properties_json(var('event_properties_to_pivot', [])) }}
    
    from dedupe

)

select * from pivot_properties