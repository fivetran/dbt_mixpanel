{{ config(enabled=var('mixpanel_sources',[]) != []) }}
-- This model is only necessary when unioning multiple sources and will therefore be disabled when that is not the case

{{
    mixpanel.union_mixpanel_connections(
        connection_dictionary=var('mixpanel_sources'), 
        single_source_name='mixpanel', 
        single_table_name='event'
    )
}}