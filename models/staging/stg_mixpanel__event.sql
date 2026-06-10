{{ config(materialized='ephemeral') }}

with events as (

    select *
    from {{ ref('stg_mixpanel__event_tmp') }}

),

fields as (

    select

        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_mixpanel__event_tmp')),
                staging_columns=get_event_columns()
            )
        }}

        {{ fivetran_utils.apply_source_relation(package_name='mixpanel') }}
        
        {{ fivetran_utils.fill_pass_through_columns('event_custom_columns') }}
        
    from events
    where {{ var('global_event_filter', 'true') }}

),

final as (

    select
        fields.*,
        cast( {{ dbt.date_trunc('day', 'occurred_at') }} as date) as date_day,
        lower(name) as event_type

    from fields
)

select *
from final