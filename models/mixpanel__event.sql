{{
    config(
        materialized='incremental',
        unique_key='unique_event_id',
        partition_by={
            "field": "date_day",
            "data_type": "date"
        }
    )
}}

with stg_event as (

    select *

    from {{ ref('stg_mixpanel__event') }}

    where 
    {% if is_incremental() %}

    -- events are only eligible for de-duping if they occurred on the same calendar day 
    occurred_at >= coalesce((select cast( max(date_day) as {{ dbt_utils.type_timestamp() }} ) from {{ this }} ) as last_date, '2010-01-01')

    {% else %}
    
    -- limit date range on the first run / refresh
    occurred_at >= {{ "'" ~ var('date_range_start',  '2010-01-01') ~ "'" }} 
    
    {% endif %}
),

dedupe as (

    select * from (

    select 
        {{ dbt_utils.surrogate_key(['insert_id', 'people_id', 'event_type', 'date_day']) }} as unique_event_id,
        *,
        
        -- aligned with mixpanel' s deduplication method: https://developer.mixpanel.com/reference/http#event-deduplication
        -- de-duping on calendar day + insert_id but also on people_id + event_type to reduce the rate of false positives 
        row_number() over(partition by insert_id, people_id, event_type, date_day order by mp_processing_time_ms asc) as nth_event_record
        
        from stg_event
    ) 
    where nth_event_record = 1

),

pivot_properties as (

    select 
        *
        {%- if var('event_properties_to_pivot', []) != [] %},{% endif %}
        {{ pivot_event_properties_json(var('event_properties_to_pivot', [])) }}
    
    from dedupe

)

select * from pivot_properties