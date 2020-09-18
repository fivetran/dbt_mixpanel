{% macro analyze_funnel(event_funnel, group_by_column=None, conversion_criteria='true' ) %}

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

grouped_events as (

    select
        {% if group_by_column != None -%}
        {{ group_by_column }},
        {% endif -%}
        event_type,
        count(insert_id) as number_of_events,
        count(distinct people_id) as number_of_users
        
    from events
    group by
    {% if group_by_column != None -%}
    {{ group_by_column }}, 
    {% endif -%}
    event_type

),

top_of_funnel as (

    select
        {{ group_by_column if group_by_column != None }},
        number_of_events as init_number_of_events,
        number_of_users as init_number_of_users

    from grouped_events
    where event_type = {{ "'" ~ event_funnel[0] ~ "'"}}
),

funnel as (

    select
        {% if group_by_column != None -%}
        {{ 'grouped_events.' ~ group_by_column }},
        {% endif -%}
        grouped_events.event_type,
        grouped_events.number_of_events,
        grouped_events.number_of_users,
        grouped_events.number_of_events * 1.0 / top_of_funnel.init_number_of_events as overall_event_pct_dropoff,
        grouped_events.number_of_users * 1.0 / top_of_funnel.init_number_of_users as overall_user_pct_dropoff,

        grouped_events.number_of_events * 1.0 / lag(grouped_events.number_of_events, 1) over (
            partition by {{ 'grouped_events.' ~ group_by_column if group_by_column != None }} 
            order by 
                case grouped_events.event_type
                {%- for event_type in event_funnel %}
                when {{ "'" ~ event_type ~ "'"}} then {{ loop.index }}
                {% endfor %}
                end ) as relative_event_pct_dropoff

    from grouped_events
    join top_of_funnel on 
    {% if group_by_column != None -%}
    {{ 'grouped_events.' ~ group_by_column }} = {{ 'top_of_funnel.' ~ group_by_column}}
    {% else %} true {% endif -%}

    order by {{ group_by_column ~ "," if group_by_column != None }}
        case grouped_events.event_type
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