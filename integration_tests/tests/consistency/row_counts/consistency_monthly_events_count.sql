{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}

-- this test is to make sure the rows counts are the same between versions
with prod as (
    select count(*) as prod_rows
    from {{ target.schema }}_mixpanel_prod.mixpanel__monthly_events
),

dev as (
    select count(*) as dev_rows
    from {{ target.schema }}_mixpanel_dev.mixpanel__monthly_events
)

-- test will return values and fail if the row counts don't match
select *
from prod
join dev
    on prod.prod_rows != dev.dev_rows