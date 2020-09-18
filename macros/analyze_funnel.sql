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

    order by 
    {% if group_by_column != None -%} {{ group_by_column }}, {% endif %}
        case event_type
        {%- for event_type in event_funnel %}
        when {{ "'" ~ event_type ~ "'"}} then {{ loop.index }}
        {% endfor %}
        end 
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
        {{ group_by_column }},
        {% endif -%}
        event_type,
        number_of_events * 1.0 / init_number_of_events as overall_pct_dropoff

    from grouped_events
    join top_of_funnel on 
    {% if group_by_column != None -%}
    {{ 'grouped_events.' ~ group_by_column }} = {{ 'top_of_funnel.' ~ group_by_column}}
    {% else %} true {% endif -%}

)


-- todo: use lag window function from https://fivetran.com/blog/funnel-analysis
select
*
from 
funnel
{% endmacro %}