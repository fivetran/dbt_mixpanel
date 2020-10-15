{% macro analyze_funnel(event_funnel, group_by_column=None, conversion_criteria='true' ) %}

-- select relevant events and applies conversion criteria as a where clause
with events as (

    select *
    from {{ ref('mixpanel__event') }}

    where (
    {% for event_type in event_funnel %}
        lower(event_type) = lower( {{ "'" ~ event_type ~ "'" }} )
    {%- if not loop.last %} OR {%- endif %}
    {% endfor %} )

    AND ( {{ conversion_criteria }} )

),

-- aggregates the number of events and users and groups by event type and the group_by_column, if given
grouped_events as (

    select
        {{ group_by_column ~ "," if group_by_column != None }}
        event_type,
        count(unique_event_id) as number_of_events,
        count(distinct people_id) as number_of_users
        
    from events
    group by
    {{ group_by_column ~ "," if group_by_column != None }}
    event_type

),

-- selects the max and previous event's metrics to compute the overall and relative funnels
build_funnel as (

    select
        {{ group_by_column ~ "," if group_by_column != None }}
        event_type,
        number_of_events,
        number_of_users,
        max(number_of_events) over({{ 'partition by ' ~ group_by_column if group_by_column != None }}) as top_of_funnel_number_of_events, 
        max(number_of_users) over({{ 'partition by ' ~ group_by_column if group_by_column != None }}) as top_of_funnel_number_of_users,

        lag(number_of_events, 1) over (
            -- only compare within groups
            {{ 'partition by ' ~ group_by_column if group_by_column != None }} order by number_of_events desc) as previous_step_number_of_events,

        lag(number_of_users, 1) over (
            -- note: ordering by number_of_users here, which *may* produce two differing funnel orders.
            {{ 'partition by ' ~ group_by_column if group_by_column != None }} order by number_of_users desc) as previous_step_number_of_users

    from grouped_events

),

-- returns the overall (event / top of funnel event) and relative (event / previous step) conversion % for each event, based on events or users
funnel as (

    select
        {{ group_by_column ~ "," if group_by_column != None }}
        event_type,
        number_of_events,
        number_of_users,

        number_of_events * 1.0 / top_of_funnel_number_of_events as overall_event_pct_conversion,
        number_of_users * 1.0 / top_of_funnel_number_of_users as overall_user_pct_conversion,

        case 
            when previous_step_number_of_events = 0 then 0 
            when previous_step_number_of_events is null then 1 -- top of funnel
            else number_of_events * 1.0 / previous_step_number_of_events end as relative_event_pct_conversion,
        
        case 
            when previous_step_number_of_users = 0 then 0 
            when previous_step_number_of_users is null then 1
            else number_of_users * 1.0 / previous_step_number_of_users end as relative_user_pct_conversion

    from build_funnel

    order by {{ group_by_column ~ "," if group_by_column != None }}
        number_of_events desc

)

select
*
from 
funnel
{% endmacro %}