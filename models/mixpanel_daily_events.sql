with stg_event as (

    select * 
    from {{ ref('stg_mixpanel_event') }}
)

-- todo: add spine
-- add criteria dictionargy


-- timeline as (

--     select  
--         event_type,
--         occurred_at,

-- )

select * from stg_event