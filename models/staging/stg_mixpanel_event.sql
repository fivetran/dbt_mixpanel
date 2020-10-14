{{ config(materialized='ephemeral') }}

with events as (

    select * 
    from {{ ref('stg_mixpanel_event_tmp') }}

),

fields as (

    select
        cast( {{ dbt_utils.date_trunc('day', 'time') }} as date) as date_day,
        lower(name) as event_type,

        -- pulls default properties and renames (see macros/staging_columns)
        -- columns missing from your source table will be completely NULL   
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_mixpanel_event_tmp')),
                staging_columns=get_event_columns()
            )
        }}

        -- custom properties as specified in your dbt_project.yml
        {%- for column in var('event_custom_columns', []) %}
        ,
        {{ column }}
        {%- endfor %}
        
    from events

    where {{ var('global_event_filter', 'true') }}

)

select * from fields
