{# {{
    config(
        materialized='incremental',
        unique_key='unique_event_id'
    )
}} #}

with stg_event as (

    select * 
    from {{ ref('stg_mixpanel_event') }}
),

pivot_properties as (
    select *,
    {{ pivot_event_properties_json(var('event_properties_to_pivot', [])) }}
    
    from stg_event

)

select * from pivot_properties