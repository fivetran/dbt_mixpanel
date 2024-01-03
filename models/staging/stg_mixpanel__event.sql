{{
    config(
        materialized='incremental',
        unique_key='_fivetran_id',
        partition_by={'field': 'date_day', 'data_type': 'date'} if target.type not in ('spark','databricks') else ['date_day'],
        incremental_strategy = 'merge' if target.type not in ('postgres', 'redshift') else 'delete+insert',
        file_format = 'delta' 
    )
}}

with events as (

    select 
        {{ dbt_utils.star(source('mixpanel', 'event')) }}
        , cast( {{ dbt.date_trunc('day', 'time') }} as date) as date_day
    from {{ source('mixpanel', 'event') }}
    where 
    {% if is_incremental() %}
    -- events are only eligible for de-duping if they occurred on the same calendar day 
    time >= coalesce((select cast( max(date_day) as {{ dbt.type_timestamp() }} ) from {{ this }} ), '2010-01-01')

    {% else %}
    -- limit date range on the first run / refresh
    time >= {{ "'" ~ var('date_range_start',  '2010-01-01') ~ "'" }}
    and time < '2023-05-09' 
    {% endif %}
),

fields as (

    select
        date_day,
        lower(name) as event_type,
        cast(time as {{ dbt.type_timestamp() }} ) as occurred_at,

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
