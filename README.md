# Mixpanel 

This package models Mixpanel data from [Fivetran's connector](https://fivetran.com/docs/applications/mixpanel). It uses data in the format described by [this ERD](https://docs.google.com/presentation/d/1WA0gCAYBy2ASlCQCPNfD1rLgyrgwRwJ_FmxTIJ1QfY8/edit#slide=id.p).

This package enables you to better understand user activity and retention through your event data. It:
- De-duplicatates events
- Pivots out custom event properties from JSONs into an enriched events table
- Creates a daily timeline of each type of event, complete with trailing and daily metrics of user activity and retention.
- Creates a monthly timeline of each type of event, complete with metrics surrounding user activity, retention, and churn.

## Models

| **model**                | **description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| mixpanel_event             | Each record represents a de-duplicated Mixpanel event. Includes the default event properties collected by Mixpanel, along with any declared custom columns and event-specific properties. |
| mixpanel_daily_events             | Each record represents a day's activity for a type of event, as reflected in user metrics. These include the number of new, repeat, and returning/resurrecting users, and also trailing 7-day and 28-day unique users. |
| mixpanel_monthly_events          | Each record represents a month of activity for a type of event, as reflected in user metrics. These include the number of new, repeat, returning/resurrecting, and churned users, and also the total active monthly users (regardless of event type). |
| mixpanel_sessions          | Each record represents a unique user session, including metrics reflecting the actions taken during the session. |

## Macros
### analyze_funnel
The `analyze_funnel(event_funnel, group_by_column, conversion_criteria)` macro can be used to produce a funnel between a given list of event types. 

It returns the following:
- The number of events and users at each step.
- The overall user and event conversion % between the top of the funnel and each step.
- The relative user and event conversion % between subsequent steps. Note: the relative order of the steps is determined by their event volume, not the order in which they are inputted.

The macro takes the following as arguments:
- `event_funnel`: List of event types (not case sensitive). Example input: `'['play_song', 'stop_song', 'exit']`
- `group_by_column`: (Optional) A column that you want to segment the funnel by (this macro pulls data from the `mixpanel_event` model). The default value is `None`.
- `conversion_criteria`: (Optional) A `WHERE` clause that will be applied when selecting from `mixpanel_event`. Example: to limit all events in the funnel to the United States, you'd provide `conversion_criteria = 'country_code = "US"'`. To limit only song play events to the US, you'd input `conversion_criteria = 'country_code = "US"' OR event_type != 'play_song'`.

## Installation Instructions
Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions, or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.

## Configuration
By default, this package will look for your Mixpanel data in the `mixpanel` schema of your [target database](https://docs.getdbt.com/docs/running-a-dbt-project/using-the-command-line-interface/configure-your-profile). If this is not where your Mixpanel data is, please add the following configuration to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:
    mixpanel_database: your_database_name
    mixpanel_schema: your_schema_name 
```

### Custom Columns
Out of the box, this package will select the [default columns collected by Mixpanel](https://help.mixpanel.com/hc/en-us/articles/115004613766-What-properties-do-Mixpanel-s-libraries-store-by-default-). However, it's likely that you have custom properties or columns that would be helpful to have in the the `mixpanel_event` model.

If there are properties in the `mixpanel.event.properties` JSON blob that you'd like to pivot out into columns, add the following variable to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:
    event_properties_to_pivot: ['the', 'list', 'of', 'property', 'fields']
```

And if there are *columns* present in your source `mixpanel.event` table that are not covered by Mixpanel default columns, add the following variable to your `dbt_project.yml` file to include them:

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:
    event_custom_columns: ['the', 'list', 'of', 'column', 'names']
```

### Event Date Range
Due to the typical volume of event data, you may want to limit this package's models to work with a more recent date range of your Mixpanel data. 

By default, the package will look at all events since 2010-01-01. To change this start date, add the following variable to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:
    date_range_start: 'yyyy-mm-dd' 
```

### Timeline Event Filters
Each of the timeline models (`mixpanel_daily_events` and `mixpanel_monthly_events`) aggregates activity metrics for each type of tracked event. However, you might want to place filters on all or individual events, or even completely filter out certain events. 

To apply criteria to events in these timeline models, add the below variable to your `dbt_project.yml` file. It will be applied as a `WHERE` clause when selecting from `mixpanel_event`.

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:

    # Example 1: Limit all events to the US
    timeline_criteria: 'country_code = "US"'

    # Example 2: Only limit 'play_song' events to the US
    timeline_criteria: 'event_type != "play_song" OR country_code = "US"'

```

## Contributions
Additional contributions to this package are very welcome! Please create issues
or open PRs against `master`. Check out 
[this post](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) 
on the best workflow for contributing to a package.

## Resources:
- Find all of Fivetran's pre-built dbt packages in our [dbt hub](https://hub.getdbt.com/fivetran/)
- Learn more about Fivetran [in the Fivetran docs](https://fivetran.com/docs)
- Check out [Fivetran's blog](https://fivetran.com/blog)
- Learn more about dbt [in the dbt docs](https://docs.getdbt.com/docs/introduction)
- Check out [Discourse](https://discourse.getdbt.com/) for commonly asked questions and answers
- Join the [chat](http://slack.getdbt.com/) on Slack for live discussions and support
- Find [dbt events](https://events.getdbt.com) near you
- Check out [the dbt blog](https://blog.getdbt.com/) for the latest news on dbt's development and best practices
