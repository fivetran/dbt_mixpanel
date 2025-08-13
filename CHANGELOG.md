# dbt_mixpanel v0.14.0
[PR #62](https://github.com/fivetran/dbt_mixpanel/pull/62) includes the following updates:

### dbt Fusion Compatibility Updates
- Updated package to maintain compatibility with dbt-core versions both before and after v1.10.6, which introduced a breaking change to multi-argument test syntax (e.g., `unique_combination_of_columns`).
- Temporarily removed unsupported tests to avoid errors and ensure smoother upgrades across different dbt-core versions. These tests will be reintroduced once a safe migration path is available.
  - Removed all `dbt_utils.unique_combination_of_columns` tests.
  - Removed all accepted_values tests.
  - Moved `loaded_at_field: _fivetran_synced` under the `config:` block in `src_mixpanel.yml`.

### Under the Hood 
- Updated conditions in `.github/workflows/auto-release.yml`.
- Added `.github/workflows/generate-docs.yml`.

# dbt_mixpanel v0.13.0

[PR #59](https://github.com/fivetran/dbt_mixpanel/pull/59) includes the following updates:

## Breaking Change for dbt Core < 1.9.6

> *Note: This is not relevant to Fivetran Quickstart users.*

Migrated `freshness` from a top-level source property to a source `config` in alignment with [recent updates](https://github.com/dbt-labs/dbt-core/issues/11506) from dbt Core. This will resolve the following deprecation warning that users running dbt >= 1.9.6 may have received:

```
[WARNING]: Deprecated functionality
Found `freshness` as a top-level property of `mixpanel` in file
`models/staging/src_mixpanel.yml`. The `freshness` top-level property should be moved
into the `config` of `mixpanel`.
```

**IMPORTANT:** Users running dbt Core < 1.9.6 will not be able to utilize freshness tests in this release or any subsequent releases, as older versions of dbt will not recognize freshness as a source `config` and therefore not run the tests.

If you are using dbt Core < 1.9.6 and want to continue running Mixpanel freshness tests, please elect **one** of the following options:
  1. (Recommended) Upgrade to dbt Core >= 1.9.6
  2. Do not upgrade your installed version of the `mixpanel` package. Pin your dependency on v0.12.0 in your `packages.yml` file.
  3. Utilize a dbt [override](https://docs.getdbt.com/reference/resource-properties/overrides) to overwrite the package's `mixpanel` source and apply freshness via the previous release top-level property route. This will require you to copy and paste the entirety of the previous release `src_mixpanel.yml` file and add an `overrides: mixpanel` property.

## Under the Hood
- Updates to ensure integration tests use latest version of dbt.

# dbt_mixpanel v0.12.0
[PR #57](https://github.com/fivetran/dbt_mixpanel/pull/57) includes the following updates:

## Breaking Changes
> To ensure all updates are applied correctly, you must run `dbt run --full-refresh` after upgrading.  
- To reduce compute, the default date spine now starts from the earliest `first_event_day` of the `stg_mixpanel__user_first_event` model instead of the fixed date `'2010-01-01'`. 
  - If you need to override this behavior, you can still set a custom `date_range_start` in your `dbt_project.yml`. See the [README](https://github.com/fivetran/dbt_mixpanel?tab=readme-ov-file#event-date-range) for more details.

## Under the Hood  
- Several variable declarations have been removed from `dbt_project.yml` as they were redundant with the inline defaults in the models. No action is needed from users.
- Removed the `date_today` macro as it is no longer necessary.

## Documentation
- Update missing definitions from `src_mixpanel.yml`.

# dbt_mixpanel v0.11.0
[PR #53](https://github.com/fivetran/dbt_mixpanel/pull/53) and [PR #55](https://github.com/fivetran/dbt_mixpanel/pull/55) include the following updates:

## Feature Update: Run Package on Unioned Connections
- This release supports running the package on multiple Mixpanel sources at once! See the [README](https://github.com/fivetran/dbt_mixpanel?tab=readme-ov-file#step-3-define-database-and-schema-variables) for details on how to leverage this feature. 
  - This was achieved through the introduction of new unioning [macros](https://github.com/fivetran/dbt_mixpanel/tree/main/macros/union).

> Please note: This is a **Breaking Change** in that we have a added a new field, `source_relation`, that points to the source connection from which the record originated. 
> This `source_relation` field is now part of all generated unique keys.
> 
> This will **require running a full refresh**.

## Documentation
- Provided missing column yml documentation.
- Added Quickstart model counts to README. ([#56](https://github.com/fivetran/dbt_mixpanel/pull/56))
- Corrected references to connectors and connections in the README. ([#56](https://github.com/fivetran/dbt_mixpanel/pull/56))

# dbt_mixpanel v0.10.0

[PR #49](https://github.com/fivetran/dbt_mixpanel/pull/49) includes the following updates:

## 🚨 Breaking Changes 🚨
> ⚠️ Since the following changes result in the table format changing, we recommend running a `--full-refresh` after upgrading to this version to avoid possible incremental failures.

- For Databricks All-Purpose clusters, incremental models will now be materialized using the delta table format (previously parquet).
  - Delta tables are generally more performant than parquet and are also more widely available for Databricks users. This will also prevent compilation issues on customers' managed tables.

- For Databricks SQL Warehouses, incremental materialization will not be used due to the incompatibility of the `insert_overwrite` strategy.

## Under the Hood
- The `is_incremental_compatible` macro has been added and will return `true` if the target warehouse supports our chosen incremental strategy.
  - This update was applied as there have been other Databricks runtimes discovered (ie. an endpoint and external runtime) which do not support the `insert_overwrite` incremental strategy used. 
- Added integration testing for Databricks SQL Warehouse.
- Added consistency tests for models:
  - `mixpanel__daily_events`
  - `mixpanel__event`
  - `mixpanel__monthly_events`
  - `mixpanel__sessions`
- Updated logic for macro `mixpanel_lookback` to align with logic used in similar macros in other packages. 

# dbt_mixpanel v0.9.0
[PR #41](https://github.com/fivetran/dbt_mixpanel/pull/41) includes the following updates:

## 🚨 Breaking Changes 🚨

> ⚠️ Since the following changes are breaking, a `--full-refresh` after upgrading will be required.

- Added a default 7-day look-back to incremental models to accommodate late arriving events. The number of days can be changed by setting the var `lookback_window` in your dbt_project.yml. See the [Lookback Window section of the README](https://github.com/fivetran/dbt_mixpanel/blob/main/README.md#lookback-window) for more details. 
  - **Note:** This replaces the variable `sessionization_trailing_window`, which was previously used in the `mixpanel__sessions` model. This variable was replaced due to the change in the incremental and lookback strategy. 

- Performance improvements:
  - Updated the incremental strategy for of the following models to `insert_overwrite` for BigQuery and Databricks and `delete+insert` for all other supported warehouses. 
    - `stg_mixpanel__user_event_date_spine`
    - `mixpanel__event`
    - `mixpanel__daily_events`
    - `mixpanel__monthly_events`
    - `mixpanel__sessions`
  - Removed `stg_mixpanel__event_tmp` in favor of ephemeral model `stg_mixpanel__event`. This is to reduce redundancy of models created and reduce the number of full scans.
  - Updated the materialization of `stg_mixpanel__user_first_event` from a table to a view. This model is used in one downstream model, so a view will reduce storage requirements while not significantly hindering performance.
  - For Snowflake and BigQuery destinations, added `cluster_by` columns to the configs for incremental models.
  - For Databricks destinations, updated incremental model file formats to `parquet` for compatibility with the `insert_overwrite` strategy.

## Feature Updates
- Added column `dbt_run_date` to incremental end models to capture the date a record was added or updated by this package.
- Added `_fivetran_id` to the `mixpanel__event` model, since this is the source `event` table's primary key as of the [March 2023 connector release notes](https://fivetran.com/docs/applications/mixpanel/changelog#march2023).

## Contributors
- [@jasongroob](https://github.com/jasongroob) ([#41](https://github.com/fivetran/dbt_mixpanel/pull/41))
- [@CraigWilson-ZOE](https://github.com/CraigWilson-ZOE) ([#38](https://github.com/fivetran/dbt_mixpanel/issues/38))

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
