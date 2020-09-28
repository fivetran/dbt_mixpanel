# Mixpanel 

This package models Mixpanel data from [Fivetran's connector](https://fivetran.com/docs/applications/mixpanel). It uses data in the format described by [this ERD](https://docs.google.com/presentation/d/1vNZeqXs3BKkfEkWCElliUw5JGYx2q3Z8EvVSzoui3wk/edit#slide=id.p).

This package enables you to better understand user activity and retention through your event data. It:
- De-duplicatates events
- Pivots out custom event properties from JSON blobs into columns
- Creates a daily timeline of each type of event, complete with metrics regarding 
and monthly timeline of activity metrics for each type of event


## Models

| **model**                | **description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| mixpanel_event             | Each record represents a de-duplicated Mixpanel event. Includes the default event properties collected by Mixpanel, along with any declared custom columns and event-specific properties. |
| mixpanel_daily_events             | Each record represents a day's activity for a type of event, as reflected in user metrics. These include the number of new, repeat, and returning/resurrecting users, and also trailing 7-day and 28-day unique users. |
| mixpanel_monthly_events          | Each record represents a month of activity for a type of event, as reflected in user metrics. These include the number of new, repeat, returning/resurrecting, and churned users, and also the total active monthly users (regardless of event type). |
| mixpanel_sessions          | Todo: Each record represents a unique user session, as defined by `session_timeout_minutes`. |

## Macros
### analyze_funnel
The `analyze_funnel(event_funnel, group_by_column, conversion_criteria)` macro can be used to produce a funnel between a given list of event types. 

Arguments:
- `event_funnel`: List of event types (case insensitive). This does not have to be in the correct order of the funnel.
- `group_by_column`: (Optional) A column in `mixpanel_event` that you want to segment the funnel by. Default is `None`.
- `conversion_criteria`: (Optional) A `WHERE` clause that will be applied when pulling data from `mixpanel_event`. To make the criteria funnel-wide, you would write something like `conversion_criteria='country_code = "US"'`, which will limit all events to the US. To apply criteria to just one event, you would write something like `conversion_criteria='country_code = "US"' OR event_type != 'play_song'`, which will limit only song plays to the US.

## Installation Instructions
Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions, or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.

## Configuration
By default, this package will look for your Asana data in the `mixpanel` schema of your [target database](https://docs.getdbt.com/docs/running-a-dbt-project/using-the-command-line-interface/configure-your-profile). If this is not where your Mixpanel data is, please add the following configuration to your `dbt_project.yml` file:

```yml
# dbt_project.yml

...
config-version: 2

vars:
  mixpanel:
    mixpanel_database: your_database_name
    mixpanel_schema: your_schema_name 
```

### Filtering Events
Variables: 
- conversion_criteria
- date_range_start

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
