{% macro analyze_funnel(event_funnel, group_by_column=None, conversion_criteria='true' ) %}

with events as (

    select *
    from {{ ref('mixpanel_event') }}

    where 
    {% for event_type in event_funnel %}
        event_type = {{ "'" ~ event_type ~ "'" }} 
    {%- if not loop.last -%} OR {%- endif %}

    AND ( conversion_criteria )

),

grouped_events as (

    select
        {% if group_by_column != None -%}
        {{ group_by_column }},
        {% endif -%}
        event_type,
        count(insert_id) as number_of_events,
        count(distinct people_id) as number_of_users,
        
    from events
    group by
    {% if group_by_column != None -%}
    {{ group_by_column }}, 
    {% endif -%}
    event_type

    order by 
    {% if group_by_column != None -%} group_by_column, {% endif %}
        case event_type
        {%- for event_type in event_funnel %}
        when {{ "'" ~ event_type ~ "'"}} then {{ loop.index + (group_by_column != None) }}
        {% endfor %}
        end 
        {% endfor %}
)
-- todo on monday: use lag window function
select
0
from 
grouped_events

{% endmacro %}