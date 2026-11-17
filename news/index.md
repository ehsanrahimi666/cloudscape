# Changelog

## cloudscape 0.2.0

- New
  [`cl_qa_obs()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_qa_obs.md)
  builds the quality-layer evidence tier: for every cell-observation it
  reads the producer quality layer (Landsat `QA_PIXEL`, Sentinel-2
  `SCL`) over the cell and records the shares of valid pixels flagged as
  cloud, cloud shadow and snow, with the share of the cell holding valid
  data. Landsat assets listed in the requester-pays USGS bucket are read
  from the Planetary Computer mirror with an anonymous access token;
  when the mirror holds another processing version of a scene, the path
  is taken from the mirror’s own catalogue record.
- [`cl_persistence()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_persistence.md)
  reports two further decorrelation times. `tau_days` fits every pair of
  acquisitions at its actual lag instead of converting a lag-1
  correlation with the median interval, and `tau_deseasonalised_days`
  measures persistence relative to a seasonal cloud probability, so that
  the seasonal cycle is not counted as persistence. Its documentation no
  longer describes the estimate as a lower bound, which holds only for
  misclassification that is independent between acquisitions.
- [`cl_pheno_power()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_power.md)
  reports the error in the timing of the seasonal peak and the median
  biases of start and end of season.
- [`cl_search()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_search.md)
  keeps each acquisition once, in its latest processing version
  (`latest = TRUE`); Earth Search lists many Sentinel-2 acquisitions of
  2019-2021 twice. It requests pages of 100 items, halves the page size
  when the catalogue answers with a gateway error, and warns when
  `limit` stops it before the last page.
- The documentation of
  [`cl_grid_index()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_grid_index.md)
  states when centroid containment agrees with exact area overlap, and
  the package description and vignettes describe the pixel-level
  detectors as experimental.
- The startup message points to
  [`?cloudscape`](https://ehsanrahimi666.github.io/cloudscape/reference/cloudscape-package.md),
  which exists, instead of a help topic that does not.
- `analysis/` holds the scripts and archived inputs of the worked
  example (Andong, Republic of Korea, 2019-2024).

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
