{% macro get_event_columns() %}

{% set columns = [

    {"name": "_fivetran_synced", "datatype": dbt.type_timestamp()},
    {"name": "ae_session_length", "datatype": dbt.type_string(), "alias": "app_session_length"},
    {"name": "app_build_number", "datatype": dbt.type_string()},

    {"name": "app_version_string", "datatype": dbt.type_string(), "alias": "app_version"},
    {"name": "bluetooth_enabled", "datatype": "boolean", "alias": "has_bluetooth_enabled"},
    {"name": "bluetooth_version", "datatype": dbt.type_string()},
    {"name": "brand", "datatype": dbt.type_string(), "alias": "device_brand"},
    {"name": "browser", "datatype": dbt.type_string()},
    {"name": "browser_version", "datatype": dbt.type_int()},
    {"name": "carrier", "datatype": dbt.type_string(), "alias": "wireless_carrier"},
    {"name": "city", "datatype": dbt.type_string()},
    {"name": "current_url", "datatype": dbt.type_string()},
    {"name": "device", "datatype": dbt.type_string(), "alias": "device_name"},
    {"name": "device_id", "datatype": dbt.type_string()},
    {"name": "distinct_id", "datatype": dbt.type_string(), "alias": "people_id"},
    {"name": "distinct_id_before_identity", "datatype": dbt.type_string(), "alias": "people_id_before_identified"},

    {"name": "google_play_services", "datatype": dbt.type_string(), "alias": "google_play_service_status"},

    {"name": "has_nfc", "datatype": "boolean", "alias": "has_near_field_communication"},
    {"name": "has_telephone", "datatype": "boolean"},
    {"name": "initial_referrer", "datatype": dbt.type_string()},
    {"name": "initial_referring_domain", "datatype": dbt.type_string()},
    {"name": "insert_id", "datatype": dbt.type_string()},
    {"name": "lib_version", "datatype": dbt.type_string(), "alias": "mixpanel_library_version"},
    {"name": "manufacturer", "datatype": dbt.type_string(), "alias": "device_manufacturer"},
    {"name": "model", "datatype": dbt.type_string(), "alias": "device_model"},
    {"name": "mp_country_code", "datatype": dbt.type_string(), "alias": "country_code"},

    {"name": "mp_keyword", "datatype": dbt.type_string(), "alias": "referrer_keywords"},
    {"name": "mp_lib", "datatype": dbt.type_string(), "alias": "mixpanel_library"},
    {"name": "mp_processing_time_ms", "datatype": dbt.type_int()},
    {"name": "name", "datatype": dbt.type_string(), "alias": "event_type_original_casing"},
    {"name": "os", "datatype": dbt.type_string()},
    {"name": "os_version", "datatype": dbt.type_string()},
    {"name": "properties", "datatype": dbt.type_string(), "alias": "event_properties"},
    {"name": "radio", "datatype": dbt.type_string(), "alias": "network_type"},
    {"name": "referrer", "datatype": dbt.type_string()},
    {"name": "referring_domain", "datatype": dbt.type_string()},
    {"name": "region", "datatype": dbt.type_string()},
    {"name": "screen_dpi", "datatype": dbt.type_int(), "alias": "screen_pixel_density"},
    {"name": "screen_height", "datatype": dbt.type_int()},
    {"name": "screen_width", "datatype": dbt.type_int()},
    {"name": "search_engine", "datatype": dbt.type_string()},
    {"name": "wifi", "datatype": "boolean", "alias": "has_wifi_connected"}
] %}

{{ return(columns) }}

{% endmacro %}
