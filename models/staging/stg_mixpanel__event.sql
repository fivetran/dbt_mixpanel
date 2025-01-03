{{ config(materialized='ephemeral') }}

with events as (

    select 
        {{ dbt_utils.star(from=ref('stg_mixpanel__event_tmp')) }}
    from {{ ref('stg_mixpanel__event_tmp') }}

),

fields as (

    select
        cast( {{ dbt.date_trunc('day', 'time') }} as date) as date_day,
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

        {{ mixpanel.apply_source_relation() }}
        
        -- custom properties as specified in your dbt_project.yml
        {{ fivetran_utils.fill_pass_through_columns('event_custom_columns') }}
        
    from events

    where {{ var('global_event_filter', 'true') }}

)

select * from fields