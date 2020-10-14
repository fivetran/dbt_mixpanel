
{{
    config(
        materialized='view'
    )
}}

{{ analyze_funnel(['Play', 'Playthrough', 'Stop'], group_by_column='country_code' ) }}

-- todo: delete this file