{% macro analyze_funnel(event_funnel, group_by_column=None, conversion_criteria='true' ) %}

-- select relevant events and applies conversion criteria as a where clause
with events as (

    select *
    from {{ ref('mixpanel_event') }}

    where 
    {% for event_type in event_funnel %}
        event_type = {{ "'" ~ event_type ~ "'" }} 
    {%- if not loop.last %} OR {%- endif %}
    {% endfor %}

    AND ( {{ conversion_criteria }} )

),

-- aggregates the number of events and users and groups by event type and the group_by_column, if given
grouped_events as (

    select
        {{ group_by_column ~ "," if group_by_column != None }}
        event_type,
        count(insert_id) as number_of_events,
        count(distinct people_id) as number_of_users
        
    from events
    group by
    {{ group_by_column ~ "," if group_by_column != None }}
    event_type

),

-- selects metrics for the event at the top of the funnel (as reflected in its order)
-- necessary for overall funnel % dropoff
top_of_funnel as (

    select
        {{ group_by_column ~ "," if group_by_column != None }}
        number_of_events as init_number_of_events,
        number_of_users as init_number_of_users

    from grouped_events
    where event_type = {{ "'" ~ event_funnel[0] ~ "'"}}
),

-- computes the overall % dropoff (compared to the top of the funnel)
-- selects the previous event's metrics to compute the relative funnel (next CTE)
build_funnel as (

    select
        {{ 'grouped_events.' ~ group_by_column ~ "," if group_by_column != None }}
        grouped_events.event_type,
        grouped_events.number_of_events,
        grouped_events.number_of_users,
        grouped_events.number_of_events * 1.0 / top_of_funnel.init_number_of_events as overall_event_pct_dropoff, -- todo: this technically isn't "dropoff" (either subtract from 1 or call it something else)
        grouped_events.number_of_users * 1.0 / top_of_funnel.init_number_of_users as overall_user_pct_dropoff,

        lag(grouped_events.number_of_events, 1) over (
            -- only compare within groups
            {{ 'partition by grouped_events.' ~ group_by_column if group_by_column != None }} 
            -- match the given order
            order by 
                case grouped_events.event_type
                {%- for event_type in event_funnel %}
                when {{ "'" ~ event_type ~ "'"}} then {{ loop.index }}
                {% endfor %}
                end ) as previous_step_number_of_events,

        lag(grouped_events.number_of_users, 1) over (
            -- only compare within groups
            {{ 'partition by grouped_events.' ~ group_by_column if group_by_column != None }} 
            order by 
            -- match the given order
                case grouped_events.event_type
                {%- for event_type in event_funnel %}
                when {{ "'" ~ event_type ~ "'"}} then {{ loop.index }}
                {% endfor %}
                end ) as previous_step_number_of_users

    from grouped_events

    join top_of_funnel on 
    -- todo: this is kinda wack -- alternative is to do a weird kind of max() window function
    {% if group_by_column != None -%}
    {{ 'grouped_events.' ~ group_by_column }} = {{ 'top_of_funnel.' ~ group_by_column}}

    {% else %} true {% endif -%}


),

-- returns the overall (event / top of funnel event) and relative (event / previous step) dropoff for each event
funnel as (

    select
        {{ group_by_column ~ "," if group_by_column != None }}
        event_type,
        number_of_events,
        number_of_users,

        overall_event_pct_dropoff,
        overall_user_pct_dropoff,

        case 
            when previous_step_number_of_events = 0 then 0 
            when previous_step_number_of_events is null then 1 -- top of funnel
            else number_of_events * 1.0 / previous_step_number_of_events end as relative_event_pct_dropoff,
        
        case 
            when previous_step_number_of_users = 0 then 0 
            when previous_step_number_of_users is null then 1
            else number_of_users * 1.0 / previous_step_number_of_users end as relative_user_pct_dropoff

    from build_funnel

    order by {{ group_by_column ~ "," if group_by_column != None }}
        case event_type
        {%- for event_type in event_funnel %}
        when {{ "'" ~ event_type ~ "'"}} then {{ loop.index }}
        {% endfor %}
        end 

)

select
*
from 
funnel
{% endmacro %}