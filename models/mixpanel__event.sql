{{
    config(
        materialized='incremental',
        unique_key='unique_event_id',
        incremental_strategy='insert_overwrite' if target.type in ('bigquery', 'spark', 'databricks') else 'delete+insert',
        partition_by={
            "field": "date_day", 
            "data_type": "date"
            } if target.type not in ('spark','databricks') 
            else ['date_day'],
        cluster_by=['date_day', 'people_id', 'event_type'] if target.type == 'snowflake' else ['people_id', 'event_type'],
        file_format='parquet'
    )
}}

with stg_event as (

    select *
    from {{ ref('stg_mixpanel__event') }}

    where 
    {% if is_incremental() %}

    -- events are only eligible for de-duping if they occurred on the same calendar day 
    occurred_at >= coalesce((select cast( max(date_day) as {{ dbt.type_timestamp() }} ) from {{ this }} ), '2010-01-01')

    {% else %}
    
    -- limit date range on the first run / refresh
    occurred_at >= {{ "'" ~ var('date_range_start',  '2010-01-01') ~ "'" }} 
    
    {% endif %}
),

dedupe as (

    select * from (

    select 
        {{ dbt_utils.generate_surrogate_key(['insert_id', 'people_id', 'event_type', 'date_day']) }} as unique_event_id,
        *,
        
        -- aligned with mixpanel' s deduplication method: https://developer.mixpanel.com/reference/http#event-deduplication
        -- de-duping on calendar day + insert_id but also on people_id + event_type to reduce the rate of false positives 
        -- using calendar day as mixpanel de-duplicates events at the end of each day
        row_number() over(partition by insert_id, people_id, event_type, date_day order by mp_processing_time_ms asc) as nth_event_record
        
        from stg_event
    ) as dupes
    where nth_event_record = 1

),

pivot_properties as (

    select 
        *
        {% if var('event_properties_to_pivot') %},
        {{ fivetran_utils.pivot_json_extract(string = 'event_properties', list_of_properties = var('event_properties_to_pivot')) }}
        {% endif %}

    from dedupe

)

select * from pivot_properties