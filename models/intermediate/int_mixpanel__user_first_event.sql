{{
    config(
        materialized='incremental' if mixpanel.is_incremental_compatible() else 'table',
        unique_key='unique_key',
        incremental_strategy='merge' if target.type in ('bigquery', 'spark', 'databricks') else 'delete+insert',
        file_format='delta'
    )
}}

-- Incremental version of stg_mixpanel__user_first_event, so incremental runs
-- don't re-scan all events. Full builds read all-time staging events, so
-- first_event_day isn't cut off by `date_range_start`.
-- depends_on: {{ ref('mixpanel__event') }}
with new_events as (

    select
        source_relation,
        people_id,
        event_type,
        min(date_day) as first_event_day,
        max(date_day) as last_event_day

    {% if is_incremental() %}
    from {{ ref('mixpanel__event') }}
    where date_day >= {{ mixpanel.mixpanel_lookback(from_date="max(last_event_day)", interval=var('lookback_window', 7), datepart='day') }}
    {% else %}
    from {{ ref('stg_mixpanel__event') }}
    {% endif %}

    group by 1,2,3
),

combined as (

    select
        new_events.source_relation,
        new_events.people_id,
        new_events.event_type,
        {% if is_incremental() %}
        -- a late event can only move the first day earlier
        least(new_events.first_event_day, coalesce(existing.first_event_day, new_events.first_event_day)) as first_event_day,
        greatest(new_events.last_event_day, coalesce(existing.last_event_day, new_events.last_event_day)) as last_event_day
        {% else %}
        new_events.first_event_day,
        new_events.last_event_day
        {% endif %}

    from new_events
    {% if is_incremental() %}
    left join {{ this }} as existing
        on new_events.people_id = existing.people_id
        and new_events.event_type = existing.event_type
        and new_events.source_relation = existing.source_relation
    {% endif %}
)

select
    *,
    {{ dbt_utils.generate_surrogate_key(['people_id', 'event_type', 'source_relation']) }} as unique_key
from combined
