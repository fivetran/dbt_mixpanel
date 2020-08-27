with event_table as (

    select * 
    from {{ var('event_table' )}}

),

rename_and_dedupe as (

    select
        insert_id,
        event_id,
        "TIME" as occurred_at,
        distinct_id as people_id,
        properties as custom_properties,
        screen_width,

        {% if var(has_android_events, true) or var(has_ios_events, true) %}
        wifi,

        app_release,
        app_version,
        os,
        mp_device_model,
        city,
        os_version,
        mp_country_code,
        lib_version,
        manufacturer,
        radio,
        carrier,
        screen_height,
        app_build_number,
        model,
        region,
        app_version_string,
        mp_lib,
        initial_referring_domain,
        device_id,
        referrer,
        current_url,
        browser,
        browser_version,
        initial_referrer,
        search_engine,
        referring_domain,
        bluetooth_version,
        has_nfc,
        brand,
        has_telephone,
        screen_dpi,
        google_play_services,
        had_persisted_distinct_id,
        bluetooth_enabled,
        ios_ifa,
        device,
        mp_keyword,
        distinct_id_before_identity

    from event_table

    {{ dbut_utils.groupby(44) }}
)