# Changelog

## cloudscape 0.1.1

- `cl_pheno_fit(model = "dbl_logistic")` now derives its starting values
  from the data. The fixed starting values used before, which placed
  green-up on day 110 and senescence on day 290, caused avoidable
  convergence failures for seasons that fall earlier or later in the
  year. The former values are kept as the last of the starting points
  tried.
- A `start` list supplied to
  [`cl_pheno_fit()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_fit.md)
  is now matched to the parameters by name. The parameter bounds were
  previously applied by position, so a list in any other order failed to
  fit. An incomplete list is now an error.
- [`cl_pheno_power()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_power.md)
  reports `insufficient_rate`, the share of replicates with too few
  usable observations to fit. Its documentation now states that
  `failure_rate` includes these replicates.
- Messages from the learned cloud detectors and from
  [`cl_benchmark()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_benchmark.md)
  no longer refer to a companion data package, which has not been
  released.
- `R CMD check` passes: a test that reads the package sources is now
  skipped outside the development tree, an expected warning is asserted
  rather than leaked, and assertions that relied on relative tolerances
  now state absolute ones. The pkgdown reference index lists every help
  topic.

## cloudscape 0.1.0

First development release.

- Equal-area analysis grid (EASE-Grid 2.0, EPSG:6933) with a closed-form
  ellipsoidal projection that requires no PROJ installation.
- Sensor driver registry: Landsat 4-9, Sentinel-2, MODIS, generic/UAV.
- Pluggable cloud-probability methods: `threshold`, `fmask`, `qa`, plus
  registered stubs for learned methods.
- Geometric cloud-shadow projection with cloud-height search, thermal
  height estimation, and explicit separation of terrain shadow from
  cloud shadow.
- Synthetic cloud and shadow simulation sharing the detector’s geometry
  kernel.
- Availability statistics: clear observations, gap distributions,
  seasonality, multi-constellation synergy, sampling feasibility.
- Phenological retrieval-error simulation.
- Evaluation with bootstrap intervals, McNemar tests and calibration
  metrics.
- `cl_stats` enforces units, sample sizes and denominators on
  construction.
