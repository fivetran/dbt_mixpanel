{{
    config(
        materialized='view'
    )
}}

select * 
from {{ var('event_table' )}}
where time >= {{ "'" ~ var('date_range_start',  '2010-01-01') ~ "'" }}
