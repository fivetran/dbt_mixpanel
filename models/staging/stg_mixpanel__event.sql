{{ config(materialized='ephemeral') }}

with events as (

    select * 
    from {{ ref('stg_mixpanel__event_tmp') }}

),

fields as (

    select
        cast( {{ dbt_utils.date_trunc('day', 'time') }} as date) as date_day,
        lower(name) as event_type,

        -- pulls default properties and renames (see macros/staging_columns)
        -- columns missing from your source table will be completely NULL   
        {{
            fivetran_utils.fill_staging_columns(
                source_columns=adapter.get_columns_in_relation(ref('stg_mixpanel__event_tmp')),
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

),

-- aliasing happens in ../../macros/staging_columns.sql
-- writing out the below for recasting
final as (

    select
        _fivetran_synced,
        app_session_length,
        app_build_number,
        app_version,
        has_bluetooth_enabled,
        bluetooth_version,
        device_brand,
        browser,
        browser_version,
        wireless_carrier,
        city,
        current_url,
        device_name,
        device_id,
        people_id,
        people_id_before_identified,
        google_play_service_status,
        has_near_field_communication,
        has_telephone,
        initial_referrer,
        initial_referring_domain,
        insert_id,
        mixpanel_library_version,
        device_manufacturer,
        device_model,
        country_code,
        referrer_keywords,
        mixpanel_library,
        mp_processing_time_ms,
        event_type_original_casing,
        os,
        os_version,
        event_properties,
        network_type,
        referrer,
        referring_domain,
        region,
        screen_pixel_density,
        screen_height,
        screen_width,
        search_engine,
        cast(time as {{ dbt_utils.type_timestamp() }} )as occurred_at,
        wifi as has_wifi_connected

    from fields

)

select * from final
