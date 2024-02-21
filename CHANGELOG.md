# dbt_mixpanel v0.9.0
[PR #41](https://github.com/fivetran/dbt_mixpanel/pull/41) includes the following updates:

## 🚨 Breaking Changes 🚨
> ⚠️ Since the following changes are breaking, we recommend running a `--full-refresh` after upgrading to this version.
- Performance improvements:
  - Updated the incremental strategy for of the following models to `insert_overwrite` for BigQuery and Databricks and `delete+insert` for all other warehouses. 
    - `stg_mixpanel__user_event_date_spine`
    - `mixpanel__event`
    - `mixpanel__daily_events`
    - `mixpanel__monthly_events`
    - `mixpanel__sessions`
  - Removed `stg_mixpanel__event_tmp` in favor of ephemeral model `stg_mixpanel__event`. This is to reduce redundancy of models created and reduce the number of full scans.
  - Updated the materialization of `stg_mixpanel__user_first_event` to a view. 
  - Added `cluster_by` columns to the configs for incremental models. This will benefit Snowflake and BigQuery users. 

## Feature Updates
- Added a default 7-day look-back to incremental models to accommodate late arriving events. The numbers of days can be changed by setting the var `lookback_window` in your dbt_project.yml. See the [Lookback Window section of the README](https://github.com/fivetran/dbt_mixpanel/blob/main/README.md#lookback-window) for more details. 
  - Note: this replaces the variable `sessionization_trailing_window`, which was previously used in the `mixpanel__sessions` model. This variable was replaced due to the change in the incremental and lookback strategy. 

# dbt_mixpanel v0.8.0
>Note: If you run into issues with this update, we suggest to try a **full refresh**.
## 🎉 Feature Updates 🎉
- Databricks and Postgres compatibility! ([PR #33](https://github.com/fivetran/dbt_mixpanel/pull/33))

## Under the Hood:
- Updated incremental strategy for the following incremental models ([PR #33](https://github.com/fivetran/dbt_mixpanel/pull/33)):
    - mixpanel__daily_events
    - mixpanel__event
    - mixpanel__monthly_events
    - mixpanel__sessions
    - stg_mixpanel__user_event_date_spine
- Incorporated the new `fivetran_utils.drop_schemas_automation` macro into the end of each Buildkite integration test job. ([PR #32](https://github.com/fivetran/dbt_mixpanel/pull/32))
- Updated the pull request [templates](/.github). ([PR #32](https://github.com/fivetran/dbt_mixpanel/pull/32))

# dbt_mixpanel v0.7.0
[PR #28](https://github.com/fivetran/dbt_mixpanel/pull/28) includes the following breaking changes:
## 🚨 Breaking Changes 🚨:
- Dispatch update for dbt-utils to dbt-core cross-db macros migration. Specifically `{{ dbt_utils.<macro> }}` have been updated to `{{ dbt.<macro> }}` for the below macros:
    - `any_value`
    - `bool_or`
    - `cast_bool_to_text`
    - `concat`
    - `date_trunc`
    - `dateadd`
    - `datediff`
    - `escape_single_quotes`
    - `except`
    - `hash`
    - `intersect`
    - `last_day`
    - `length`
    - `listagg`
    - `position`
    - `replace`
    - `right`
    - `safe_cast`
    - `split_part`
    - `string_literal`
    - `type_bigint`
    - `type_float`
    - `type_int`
    - `type_numeric`
    - `type_string`
    - `type_timestamp`
    - `array_append`
    - `array_concat`
    - `array_construct`
- For `current_timestamp` and `current_timestamp_in_utc` macros, the dispatch AND the macro names have been updated to the below, respectively:
    - `dbt.current_timestamp_backcompat`
    - `dbt.current_timestamp_in_utc_backcompat`
- `dbt_utils.surrogate_key` has also been updated to `dbt_utils.generate_surrogate_key`. Since the method for creating surrogate keys differ, we suggest all users do a `full-refresh` for the most accurate data. For more information, please refer to dbt-utils [release notes](https://github.com/dbt-labs/dbt-utils/releases) for this update.
- Dependencies on `fivetran/fivetran_utils` have been upgraded, previously `[">=0.3.0", "<0.4.0"]` now `[">=0.4.0", "<0.5.0"]`.

## 🎉 Documentation and Feature Updates 🎉:
- Updated README documentation for easier navigation and dbt package setup.
- Included the `mixpanel_[source_table_name]_identifier` variables for easier flexibility of the package models to refer to differently named sources tables.

# dbt_mixpanel v0.6.1
🎉 LISTAGG fix 🎉
## Fixes
- Redshift and Postgres warehouses have a limit to the amount of aggregation that may take place within certain functions. The `mixpanel__sessions` model currently performs a LISTAGG and customers have identified the aggregation sometimes exceeds the limit of the function. Therefore, a conditional was added to check if the target type is Redshift or Postgres. If it is either, it will only perform the aggregation if the count is less than the amount defined by the `mixpanel__event_frequency_limit` (default 1000) variable. Otherwise, it will return 'Too many event types to render'. ([#27](https://github.com/fivetran/dbt_mixpanel/pull/27))
# dbt_mixpanel v0.6.0
🎉 dbt v1.0.0 Compatibility 🎉
## 🚨 Breaking Changes 🚨
- Adjusts the `require-dbt-version` to now be within the range [">=1.0.0", "<2.0.0"]. Additionally, the package has been updated for dbt v1.0.0 compatibility. If you are using a dbt version <1.0.0, you will need to upgrade in order to leverage the latest version of the package.
  - For help upgrading your package, I recommend reviewing this GitHub repo's Release Notes on what changes have been implemented since your last upgrade.
  - For help upgrading your dbt project to dbt v1.0.0, I recommend reviewing dbt-labs [upgrading to 1.0.0 docs](https://docs.getdbt.com/docs/guides/migration-guide/upgrading-to-1-0-0) for more details on what changes must be made.
- Upgrades the package dependency to refer to the latest `dbt_fivetran_utils`. The latest `dbt_fivetran_utils` package also has a dependency on `dbt_utils` [">=0.8.0", "<0.9.0"].
  - Please note, if you are installing a version of `dbt_utils` in your `packages.yml` that is not in the range above then you will encounter a package dependency error.

# dbt_mixpanel v0.1.0 -> v0.5.0
Refer to the relevant release notes on the Github repository for specific details for the previous releases. Thank you!
