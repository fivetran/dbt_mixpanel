{% macro apply_source_relation() -%}

{{ adapter.dispatch('apply_source_relation', 'mixpanel') () }}

{%- endmacro %}

{% macro default__apply_source_relation() -%}

{% if var('mixpanel_sources', []) != [] %}
, _dbt_source_relation as source_relation
{% else %}
, '{{ var("mixpanel_database", target.database) }}' || '.'|| '{{ var("mixpanel_schema", "mixpanel") }}' as source_relation
{% endif %} 

{%- endmacro %}