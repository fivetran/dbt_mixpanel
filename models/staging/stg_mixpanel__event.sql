{{ config(
        materialized='incremental',
        unique_key='_fivetran_id',
        incremental_strategy='insert_overwrite' if target.type in ('bigquery', 'spark', 'databricks') else 'delete+insert',
        partition_by={
            "field": "date_day", 
            "data_type": "date"
            } if target.type not in ('spark','databricks') 
            else ['date_day'],
        cluster_by=['date_day', 'event_type'] if target.type == 'snowflake' else ['event_type'],
        file_format='parquet'
    )
}}

with events as (

    select 
        {{ dbt_utils.star(from=source('mixpanel', 'event')) }}
    from {{ var('event_table') }}

    {% if is_incremental() %}
    where cast(time as {{ dbt.type_timestamp() }}) >= (select max(cast((date_day) as {{ dbt.type_timestamp() }})) from {{ this }})
    {% else %}
    where cast(time as {{ dbt.type_timestamp() }} ) >= {{ "'" ~ var('date_range_start',  '2010-01-01') ~ "'" }}
    {% endif %}
),

fields as (

    select
        cast( {{ dbt.date_trunc('day', 'time') }} as date) as date_day,
        cast(time as {{ dbt.type_timestamp() }} ) as occurred_at,
        lower(name) as event_type,

        -- pulls default properties and renames (see macros/staging_columns)
        -- columns missing from your source table will be completely NULL   
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(source('mixpanel', 'event')),
                staging_columns=get_event_columns()
            )
        }}

        -- custom properties as specified in your dbt_project.yml
        {{ fivetran_utils.fill_pass_through_columns('event_custom_columns') }}
        
    from events

    where {{ var('global_event_filter', 'true') }}

)

select * from fields
