with event_table as (

    select * 
    from {{ var('event_table' )}}

),

fields as (

    select
        -- shared default events across platforms - 13
        insert_id,
        time as occurred_at,
        distinct_id as people_id,
        properties as custom_properties,
        screen_width,
        os,
        city,
        mp_country_code as country_code,
        screen_height,
        region,
        mp_lib as mixpanel_library,
        device_id,
        -- had_persisted_distinct_id, -- this was a bug from mixpanel apparently 
        distinct_id_before_identity as people_id_before_identified

        {%- if var(has_web_events, true) -%}
        ,

        -- web-only default events - 10
        initial_referring_domain,
        referring_domain,
        initial_referrer,
        referrer,
        mp_keyword as referrer_keywords,
        search_engine,
        current_url,
        browser,
        browser_version,
        device as device_name
        {%- endif -%}
        {%- if var(has_android_events, true) or var(has_ios_events, true) -%}
        ,

        -- mobile-only default events - 8
        wifi as has_wifi_connected,
        -- app_release, -- deprecated 
        -- app_version, -- deprecated in favor of string
        app_version_string as app_version,
        -- mp_device_model, -- legacy, = model 
        os_version,
        lib_version as mixpanel_library_version,
        manufacturer as device_manufacturer,
        carrier as wireless_carrier,
        app_build_number,
        model as device_model
        {%- endif -%}
        {%- if var(has_ios_events, true) -%}
        ,

        -- ios-only default events - 2
        radio as network_type,
        -- ios_ifa -- todo: remove
        {%- endif -%}
        {%- if var(has_android_events, true) -%}
        ,

        -- android-only default events - 7
        bluetooth_version,
        has_nfc as has_near_field_communication,
        brand as device_brand,
        has_telephone as has_telephone,
        screen_dpi as screen_pixel_density,
        google_play_services as google_play_service_status,
        bluetooth_enabled as has_bluetooth_enabled
        {%- endif %}

        {% for column in var(custom_event_columns, []) -%}
        ,
        {{ column }}
        {%- endfor %}
        {{ log( var(custom_event_columns), info=true) }}
        
    from event_table
),

deduped as (

    select * 
    from fields

    {%- set groupby_n = 13 + var(has_web_events, true) * 10 + var(has_ios_events, true) * 2 + 
        var(has_android_events, true) * 7 + (var(has_android_events, true) or var(has_ios_events, true)) * 8 %}

    {{ dbt_utils.group_by(groupby_n) }}
)

select * from deduped
