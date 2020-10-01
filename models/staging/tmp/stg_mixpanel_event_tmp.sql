select * 
from {{ var('event_table' )}}

-- limit date range
where time > {{ "'" ~ var('date_range_start',  '2010-01-01') ~ "'" }} 