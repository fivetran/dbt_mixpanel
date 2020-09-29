-- probably want to config this as ephemeral.. or consolidate with mixpanel_event

with events as (

    select * 
    from {{ var('event_table' )}}

    -- limit date range
    where time > {{ "'" ~ var('date_range_start',  '2010-01-01') ~ "'" }} 

),

dedupe as (

    select * from (

    select 
        *,
        -- aligned with mixpanel's deduplication method: https://developer.mixpanel.com/reference/http#event-deduplication
        row_number() over(partition by insert_id, distinct_id, name order by mp_processing_time_ms asc) as nth_event_record
        
        from events
    ) 
    where nth_event_record = 1

),

-- selects default properties collected by mixpanel for each appropriate platform -- TODO: use fill_staging_columns macro for this
-- and any additional custom columns specified in your dbt_project.yml
fields as (

    select
        -- shared default events across platforms - 14
        insert_id || '-' || {{ dbt_utils.date_trunc('day', 'time') }} as unique_event_id,
        insert_id,
        time as occurred_at,
        lower(name) as event_type,
        distinct_id as people_id,
        properties as event_properties,
        city,
        mp_country_code as country_code,
        region,
        mp_lib as mixpanel_library,
        device_id,
        screen_width,
        screen_height,
        os,

        -- todo: incorporate macro for all columns once pushed to its pushed to dbt_fivetran_utils
        distinct_id_before_identity as people_id_before_identified

        {%- if var('has_web_events', true) -%}
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
        {%- if var('has_android_events', true) or var('has_ios_events', true) -%}
        ,

        -- mobile-only default events - 9
        wifi as has_wifi_connected,
        app_version_string as app_version,
        app_build_number,
        os_version,
        lib_version as mixpanel_library_version,
        manufacturer as device_manufacturer,
        carrier as wireless_carrier,
        model as device_model,
        ae_session_length as app_session_length
        {%- endif -%}
        {%- if var('has_ios_events', true) -%}
        ,

        -- ios-only default events - 1
        radio as network_type
        {%- endif -%}
        {%- if var('has_android_events', true) -%}
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

        -- custom properties as specified in your dbt_project.yml
        {%- for column in var('event_custom_columns', []) %}
        ,
        {{ column }}
        {%- endfor %}
        
    from dedupe
)

select * from fields
