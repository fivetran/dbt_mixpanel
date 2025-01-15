{{ config(enabled=var('mixpanel_sources',[]) != []) }}

{{
    mixpanel.union_mixpanel_connections(
        connection_dictionary=var('mixpanel_sources'), 
        single_source_name='mixpanel', 
        single_table_name='event'
    )
}}