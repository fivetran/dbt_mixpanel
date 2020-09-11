{% macro analyze_funnel(list_of_events, group_by_columns=[], conversion_criteria='true' ) %}

with events as (

    select *
    from {{ ref('mixpanel_event') }}

    where 
    {% for event_type in list_of_events %}
        event_type = {{ event_type }} 
    {%- if not loop.last -%} OR {%- endif %}
    AND ( conversion_criteria )
)

select

from 

{% endmacro %}