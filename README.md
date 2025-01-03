<p align="center">
    <a alt="License"
        href="https://github.com/fivetran/dbt_mixpanel/blob/main/LICENSE">
        <img src="https://img.shields.io/badge/License-Apache%202.0-blue.svg" /></a>
    <a alt="dbt-core">
        <img src="https://img.shields.io/badge/dbt_Core™_version->=1.3.0_<2.0.0-orange.svg" /></a>
    <a alt="Maintained?">
        <img src="https://img.shields.io/badge/Maintained%3F-yes-green.svg" /></a>
    <a alt="PRs">
        <img src="https://img.shields.io/badge/Contributions-welcome-blueviolet" /></a>
    <a alt="Fivetran Quickstart Compatible"
        href="https://fivetran.com/docs/transformations/dbt/quickstart">
        <img src="https://img.shields.io/badge/Fivetran_Quickstart_Compatible%3F-yes-green.svg" /></a>
</p>

# Mixpanel dbt Package ([Docs](https://fivetran.github.io/dbt_mixpanel/))
## What does this dbt package do?

- Produces modeled tables that leverage Mixpanel data from [Fivetran's connector](https://fivetran.com/docs/applications/mixpanel). It uses the Mixpanel `event` table in the format described by [this ERD](https://fivetran.com/docs/applications/mixpanel#schemainformation).

- Enables you to better understand user activity and retention through your event data. It:
  - Creates both a daily and monthly timeline of each type of event, complete with metrics about user activity, retention, resurrection, and churn
  - Aggregates events into unique user sessions, complete with metrics about event frequency and any relevant fields from the session's first event
  - Provides a macro to easily create an event funnel
  - De-duplicates events according to [best practices from Mixpanel](https://developer.mixpanel.com/reference/http#event-deduplication)
  - Pivots out custom event properties from JSONs into an enriched events table

<!--section="mixpanel_transformation_model-->
- Generates a comprehensive data dictionary of your source and modeled Mixpanel data through the [dbt docs site](https://fivetran.github.io/dbt_mixpanel/#!/overview).
The following table provides a detailed list of all tables materialized within this package by default.
> TIP: See more details about these tables in the package's [dbt docs site](https://fivetran.github.io/dbt_mixpanel/#!/overview?g_v=1).

| **Table**                | **Description**                                                                                                                                |
| ------------------------ | ---------------------------------------------------------------------------------------------------------------------------------------------- |
| [mixpanel__event](https://fivetran.github.io/dbt_mixpanel/#!/model/model.mixpanel.mixpanel__event)             | Each record represents a de-duplicated Mixpanel event. This includes the default event properties collected by Mixpanel, along with any declared custom columns and event-specific properties. |
| [mixpanel__daily_events](https://fivetran.github.io/dbt_mixpanel/#!/model/model.mixpanel.mixpanel__daily_events)             | Each record represents a day's activity for a type of event, as reflected in user metrics. These include the number of new, repeat, and returning/resurrecting users, as well as trailing 7-day and 28-day unique users. |
| [mixpanel__monthly_events](https://fivetran.github.io/dbt_mixpanel/#!/model/model.mixpanel.mixpanel__monthly_events)          | Each record represents a month of activity for a type of event, as reflected in user metrics. These include the number of new, repeat, returning/resurrecting, and churned users, as well as the total active monthly users (regardless of event type). |
| [mixpanel__sessions](https://fivetran.github.io/dbt_mixpanel/#!/model/model.mixpanel.mixpanel__sessions)          | Each record represents a unique user session, including metrics reflecting the frequency and type of actions taken during the session and any relevant fields from the session's first event. |

<!--section-end-->

## How do I use the dbt package?

### Step 1: Prerequisites
To use this dbt package, you must have the following:

- At least one Fivetran Mixpanel connector syncing data into your destination.
- A **BigQuery**, **Snowflake**, **Redshift**, **PostgreSQL**, or **Databricks** destination.

#### Databricks dispatch configuration
If you are using a Databricks destination with this package, you must add the following (or a variation of the following) dispatch configuration within your `dbt_project.yml`. This is required in order for the package to accurately search for macros within the `dbt-labs/spark_utils` then the `dbt-labs/dbt_utils` packages respectively.
```yml
dispatch:
  - macro_namespace: dbt_utils
    search_order: ['spark_utils', 'dbt_utils']
```

#### Database Incremental Strategies
Many of the models in this package are materialized incrementally, so we have configured our models to work with the different strategies available to each supported warehouse.

For **BigQuery** and **Databricks All Purpose Cluster runtime** destinations, we have chosen `insert_overwrite` as the default strategy, which benefits from the partitioning capability.
> For Databricks SQL Warehouse destinations, models are materialized as tables without support for incremental runs.

For **Snowflake**, **Redshift**, and **Postgres** databases, we have chosen `delete+insert` as the default strategy.

> Regardless of strategy, we recommend that users periodically run a `--full-refresh` to ensure a high level of data quality.

### Step 2: Install the package
Include the following mixpanel package version in your `packages.yml` file:
> TIP: Check [dbt Hub](https://hub.getdbt.com/) for the latest installation instructions or [read the dbt docs](https://docs.getdbt.com/docs/package-management) for more information on installing packages.

```yaml
packages:
  - package: fivetran/mixpanel
    version: [">=0.11.0", "<0.12.0"] # we recommend using ranges to capture non-breaking changes automatically
```

### Step 3: Define database and schema variables
#### Option A: Single connector
By default, this package runs using your destination and the `mixpanel` schema. If this is not where your Mixpanel data is (for example, if your Mixpanel schema is named `mixpanel_fivetran`), add the following configuration to your root `dbt_project.yml` file:

```yml
vars:
    mixpanel_database: your_database_name
    mixpanel_schema: your_schema_name 
```

#### Option B: Union multiple connectors
If you have multiple Mixpanel connectors in Fivetran and would like to use this package on all of them simultaneously, we have provided functionality to do so. For each source table, the package will union all of the data together and pass the unioned table into the transformations. The `source_relation` column in each model indicates the origin of each record.

To use this functionality, you will need to set the `mixpanel_sources` variable in your root `dbt_project.yml` file:

```yml
# dbt_project.yml

vars:
  mixpanel_sources:
    - database: connector_1_destination_name # Required
      schema: connector_1_schema_name # Rquired
      name: connector_1_source_name # Required only if following the step in the following subsection

    - database: connector_2_destination_name
      schema: connector_2_schema_name
      name: connector_2_source_name
```

##### Recommended: Incorporate unioned sources into DAG
> *If you are running the package through [Fivetran Transformations for dbt Core™](https://fivetran.com/docs/transformations/dbt#transformationsfordbtcore), the below step is necessary in order to synchronize model runs with your Mixpanel connectors. Alternatively, you may choose to run the package through Fivetran [Quickstart](https://fivetran.com/docs/transformations/quickstart), which would create separate sets of models for each Mixpanel source rather than one set of unioned models.*

By default, this package defines one single-connector source, called `mixpanel`, which will be disabled if you are unioning multiple connectors. This means that your DAG will not include your Mixpanel sources, though the package will run successfully.

To properly incorporate all of your Mixpanel connectors into your project's DAG:
1. Define each of your sources in a `.yml` file in your project. Utilize the following template for the `source`-level configurations, and, **most importantly**, copy and paste the table and column-level definitions from the package's `src_mixpanel.yml` [file](https://github.com/fivetran/dbt_mixpanel/blob/main/models/staging/src_mixpanel.yml). This package currently only uses the `EVENT` source table.

```yml
# a .yml file in your root project
sources:
  - name: <name> # ex: Should match name in mixpanel_sources
    schema: <schema_name>
    database: <database_name>
    loader: fivetran
    loaded_at_field: _fivetran_synced
      
    freshness: # feel free to adjust to your liking
      warn_after: {count: 72, period: hour}
      error_after: {count: 168, period: hour}

    tables: 
      - name: event
        description: Table of all events tracked by Mixpanel across web, ios, and android platforms.
        columns: # copy and paste from mixpanel/models/staging/src_mixpanel.yml - see https://support.atlassian.com/bitbucket-cloud/docs/yaml-anchors/ for how to use anchors to only do so once
```

2. Set the `has_defined_sources` variable (scoped to the `mixpanel` package) to `True`, like such:
```yml
# dbt_project.yml
vars:
  mixpanel:
    has_defined_sources: true
```

### (Optional) Step 4: Additional configurations
<details open><summary>Collapse/expand details</summary>

### Macros
#### analyze_funnel [(source)](https://github.com/fivetran/dbt_mixpanel/blob/master/macros/analyze_funnel.sql)
You can use the `analyze_funnel(event_funnel, group_by_column, conversion_criteria)` macro to produce a funnel between a given list of event types.

It returns the following:
- The number of events and users at each step
- The overall user and event conversion % between the top of the funnel and each step
- The relative user and event conversion % between subsequent steps
> Note: The relative order of the steps is determined by their event volume, not the order in which they are input.

The macro takes the following as arguments:
- `event_funnel`: List of event types (not case sensitive).
  - Example: `'['play_song', 'stop_song', 'exit']`
- `group_by_column`: (Optional) A column by which you want to segment the funnel (this macro pulls data from the `mixpanel__event` model). The default value is `None`.
  - Example: `group_by_column = 'country_code'`.
- `conversion_criteria`: (Optional) A `WHERE` clause that will be applied when selecting from `mixpanel__event`.
  - Example: To limit all events in the funnel to the United States, you'd provide `conversion_criteria = 'country_code = "US"'`. To limit the events to only song play events to the US, you'd input `conversion_criteria = 'country_code = "US"' OR event_type != 'play_song'`.

#### Pivoting Out Event Properties
By default, this package selects the [default columns collected by Mixpanel](https://help.mixpanel.com/hc/en-us/articles/115004613766-What-properties-do-Mixpanel-s-libraries-store-by-default-). However, you likely have custom properties or columns that you'd like to include in the `mixpanel__event` model.

If there are properties in the `mixpanel.event.properties` JSON blob that you'd like to pivot out into columns, add the following variable to your `dbt_project.yml` file:

```yml
vars:
  mixpanel:
    event_properties_to_pivot: ['the', 'list', 'of', 'property', 'fields'] # Note: this is case-SENSITIVE and must match the casing of the property as it appears in the JSON
```

#### Passthrough Columns
Additionally, this package includes all standard source `EVENT` columns defined in the `staging_columns` macro. You can add more columns using our passthrough column variables. These variables allow the passthrough fields to be aliased (`alias`) and casted (`transform_sql`) if desired, although it is not required. Data type casting is configured via a SQL snippet within the `transform_sql` key. You may add the desired SQL snippet while omitting the `as field_name` part of the casting statement - this will be dealt with by the alias attribute - and your custom passthrough fields will be casted accordingly.

Use the following format for declaring the respective passthrough variables:

```yml
vars:
  mixpanel:
    event_custom_columns:
      - name:           "property_field_id"
        alias:          "new_name_for_this_field_id"
        transform_sql:  "cast(property_field_id as int64)"
      - name:           "this_other_field"
        transform_sql:  "cast(this_other_field as string)"
```
#### Sessions Event Frequency Limit
The `event_frequencies` field within the `mixpanel__sessions` model reports all event types and the frequency of those events as a JSON blob via a string aggregation. For some users there can be thousands of different event types that take place. For Redshift and Postgres warehouses there currently exists a limit for string aggregations (up to 65,535). As a result, in order for Redshift and Postgres users to still leverage the `event_frequencies` field, an artificial limit is applied to this field of 1,000. If you would like to adjust this limit, you may do so by modifying the below variable in your project configuration.
```yml
vars:
  mixpanel:
    mixpanel__event_frequency_limit: 500 ## Default is 1000
```
#### Event Date Range
Because of the typical volume of event data, you may want to limit this package's models to work with a recent date range of your Mixpanel data (however, note that all final models are materialized as [incremental](https://docs.getdbt.com/docs/building-a-dbt-project/building-models/materializations#incremental) tables).

By default, the package looks at all events since January 1, 2010. To change this start date, add the following variable to your `dbt_project.yml` file:

```yml
vars:
  mixpanel:
    date_range_start: 'yyyy-mm-dd' 
```

**Note:** This date range will not affect the `number_of_new_users` column in the `mixpanel__daily_events` or `mixpanel__monthly_events` models. This metric will be *true* new users.

#### Global Event Filters
In addition to limiting the date range, you may want to employ other filters to remove noise from your event data.

To apply a global filter to events (and therefore **all** models in this package), add the following variable to your `dbt_project.yml` file. It will be applied as a `WHERE` clause when selecting from the source table, `mixpanel.event`.

```yml
vars:
  mixpanel:
    # Ex: removing internal user
    global_event_filter: 'distinct_id != "1234abcd"'
```

#### Session Configurations
##### Session Inactivity Timeout
This package sessionizes events based on the periods of inactivity between a user's events on a device. By default, the package will denote a new session once the period between events surpasses **30 minutes**.

To change this timeout value, add the following variable to your `dbt_project.yml` file:

```yml
vars:
  mixpanel:
    sessionization_inactivity: number_of_minutes # ex: 60
```

##### Session Pass-Through Columns
By default, the `mixpanel__sessions` model will contain the following columns from `mixpanel__event`:
- `people_id`: The ID of the user
- `device_id`: The ID of the device they used in this session
- `event_frequencies`: A JSON of the frequency of each `event_type` in the session

To pass through any additional columns from the events table to `mixpanel__sessions`, add the following variable to your `dbt_project.yml` file. The value of each field will be pulled from the first event of the session.

```yml
vars:
  mixpanel:
    session_passthrough_columns: ['the', 'list', 'of', 'column', 'names'] 
```

##### Session Event Criteria
In addition to any global event filters, you may want to disclude events or place filters on them in order to qualify for sessionization.

To apply any filters to the events in the sessions model, add the following variable to your `dbt_project.yml` file. It will be applied as a `WHERE` clause when selecting from `mixpanel__event`.

```yml
vars:
  mixpanel:

    # ex: limit sessions to include only these kinds of events
    session_event_criteria: 'event_type in ("play_song", "stop_song", "create_playlist")'
```

##### Lookback Window
Events can sometimes arrive late. For example, events triggered on a mobile device that is offline will be sent to Mixpanel once the device reconnects to wifi or a cell network. Since many of the models in this package are incremental, by default we look back 7 days to ensure late arrivals are captured while avoiding requiring a full refresh. To change the default lookback window, add the following variable to your `dbt_project.yml` file:

```yml
vars:
  mixpanel:
    lookback_window: number_of_days # default is 7
```

#### Changing the Build Schema
By default this package will build the Mixpanel staging models within a schema titled (<target_schema> + `_stg_mixpanel`) and Mixpanel final models within a schema titled (<target_schema> + `mixpanel`) in your target database. If this is not where you would like your modeled Mixpanel data to be written to, add the following configuration to your `dbt_project.yml` file:

```yml
models:
    mixpanel:
      +schema: my_new_schema_name # leave blank for just the target_schema
      staging:
        +schema: my_new_schema_name # leave blank for just the target_schema
```

#### Change the source table references
If an individual source table has a different name than the package expects, add the table name as it appears in your destination to the respective variable:

> IMPORTANT: See this project's [`dbt_project.yml`](https://github.com/fivetran/dbt_mixpanel/blob/main/dbt_project.yml) variable declarations to see the expected names.

```yml
vars:
    mixpanel_<default_source_table_name>_identifier: your_table_name 
```

### Event De-Duplication Logic

Events are considered duplicates and consolidated by the package if they contain the same:
* `insert_id` (used for de-deuplication internally by Mixpanel)
* `people_id` (originally named `distinct_id`)
* type of event
* calendar date of occurrence (event timestamps are set in the timezone the Mixpanel project is configured to)

This is performed in line with Mixpanel's internal de-duplication process, in which events are de-duped at the end of each day. This means that if an event was triggered during an offline session at 11:59 PM and _resent_ when the user came online at 12:01 AM, these records would _not_ be de-duplicated. This is the case in both Mixpanel and the Mixpanel dbt package.
</details>

### (Optional) Step 5: Orchestrate your models with Fivetran Transformations for dbt Core™
<details><summary>Expand for details</summary>
<br>
    
Fivetran offers the ability for you to orchestrate your dbt project through [Fivetran Transformations for dbt Core™](https://fivetran.com/docs/transformations/dbt). Learn how to set up your project for orchestration through Fivetran in our [Transformations for dbt Core setup guides](https://fivetran.com/docs/transformations/dbt#setupguide).
</details>

## Does this package have dependencies?
This dbt package is dependent on the following dbt packages. These dependencies are installed by default within this package. For more information on the following packages, refer to the [dbt hub](https://hub.getdbt.com/) site.
> IMPORTANT: If you have any of these dependent packages in your own `packages.yml` file, we highly recommend that you remove them from your root `packages.yml` to avoid package version conflicts.
    
```yml
packages:
    - package: fivetran/fivetran_utils
      version: [">=0.4.0", "<0.5.0"]

    - package: dbt-labs/dbt_utils
      version: [">=1.0.0", "<2.0.0"]
```
## How is this package maintained and can I contribute?
### Package Maintenance
The Fivetran team maintaining this package _only_ maintains the latest version of the package. We highly recommend you stay consistent with the [latest version](https://hub.getdbt.com/fivetran/mixpanel/latest/) of the package and refer to the [CHANGELOG](https://github.com/fivetran/dbt_mixpanel/blob/main/CHANGELOG.md) and release notes for more information on changes across versions.

### Contributions
A small team of analytics engineers at Fivetran develops these dbt packages. However, the packages are made better by community contributions.

We highly encourage and welcome contributions to this package. Check out [this dbt Discourse article](https://discourse.getdbt.com/t/contributing-to-a-dbt-package/657) on the best workflow for contributing to a package.

## Are there any resources available?
- If you have questions or want to reach out for help, see the [GitHub Issue](https://github.com/fivetran/dbt_mixpanel/issues/new/choose) section to find the right avenue of support for you.
- If you would like to provide feedback to the dbt package team at Fivetran or would like to request a new dbt package, fill out our [Feedback Form](https://www.surveymonkey.com/r/DQ7K7WW).
