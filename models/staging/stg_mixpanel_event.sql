{# {{ config(materialized='ephemeral') }} #}

with events as (

    select * 
    from {{ ref('stg_mixpanel_event_tmp') }}

),

dedupe as (

    select * from (

    select 
        *,
        -- aligned with mixpanel's deduplication method: https://developer.mixpanel.com/reference/http#event-deduplication
        -- really de-duping on calendar day + insert_id, but including distinct_id + name reduces the rate of false positives ^
        row_number() over(partition by insert_id, distinct_id, name, {{ dbt_utils.date_trunc('day', 'time') }} order by mp_processing_time_ms asc) as nth_event_record
        
        from events
    ) 
    where nth_event_record = 1

),

-- selects default properties collected by mixpanel for each appropriate platform
-- and any additional custom columns specified in your dbt_project.yml
fields as (

    select
        -- new PK
        insert_id || '-' || {{ dbt_utils.date_trunc('day', 'time') }} as unique_event_id,

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
        
    from dedupe
)

select * from fields
