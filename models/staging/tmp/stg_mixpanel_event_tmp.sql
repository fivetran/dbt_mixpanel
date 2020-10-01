{{
    config(
        materialized='view'
    )
}}

select * 
from {{ var('event_table' )}}