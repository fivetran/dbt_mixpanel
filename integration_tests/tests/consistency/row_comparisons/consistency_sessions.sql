{{ config(
    tags="fivetran_validations",
    enabled=var('fivetran_validation_tests_enabled', false)
) }}
{% set exclude_fields = ["event_frequencies", "source_relation","session_id"] %}
{% set fields = dbt_utils.star(from=ref('mixpanel__sessions'), except=exclude_fields) %}

-- this test ensures the daily_activity end model matches the prior version
with prod as (
    select {{ fields }}
    from {{ target.schema }}_mixpanel_prod.mixpanel__sessions
),

dev as (
    select {{ fields }}
    from {{ target.schema }}_mixpanel_dev.mixpanel__sessions
),

prod_not_in_dev as (
    -- rows from prod not found in dev
    select * from prod
    except distinct
    select * from dev
),

dev_not_in_prod as (
    -- rows from dev not found in prod
    select * from dev
    except distinct
    select * from prod
),

final as (
    select
        *,
        'from prod' as source
    from prod_not_in_dev

    union all -- union since we only care if rows are produced

    select
        *,
        'from dev' as source
    from dev_not_in_prod
)

select *
from final