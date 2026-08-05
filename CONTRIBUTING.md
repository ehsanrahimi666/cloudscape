# Contributing to cloudscape

Bug reports and pull requests are welcome.

## Reporting a bug

Please include a minimal reproducible example and the output of
`sessionInfo()`. If the bug involves catalogue access, state which backend
(`cl_catalog()$backend`) and paste the `cl_manifest()` of the affected object,
which records the endpoint, collection and access time.

## Pull requests

* Run `Rscript tools/offline-check.R` before opening a PR. It runs the full
  test suite using only base R.
* New functionality needs a test. Tests must not make network calls; use the
  fixtures in `tests/testthat/helper-fixtures.R` or synthetic data.
* The package has a layer contract described in `DESIGN.md` and enforced by
  `tools/architecture.R`. A lower layer must never call into a higher one.
  `Rscript -e 'source("tools/architecture.R"); cs_check_layers("R")'` must
  return zero rows.
* Every exported function needs `@param` for each argument and a `@return`.
  `cs_check_docs("R")` must also return zero rows.

## Adding a sensor

Sensors are drivers, not code paths. Write one `cl_sensor_driver()` entry with
the band map, QA specification and platform commissioning dates, register it in
`.cs_register_builtin()`, and add a line to the sensor table in the README.
No algorithm should need to change.
