# Changelog

## cloudscape 0.3.0

### Usability of partly observed cells

- [`cl_clear_obs()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_obs.md),
  [`cl_gaps()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_gaps.md),
  [`cl_persistence()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_persistence.md)
  and
  [`cl_seasonality()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_seasonality.md)
  gain `coverage = TRUE`: a cell-observation is usable when at least
  `1 - threshold` of the whole cell was observed and cloud-free, so that
  a cell seen over part of its area cannot pass on the cloud fraction of
  that part alone.
  [`cl_clear_prob()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_prob.md)
  multiplies by the valid share of the cell.
- Seasons (`by = "season"`) are meteorological (DJF, MAM, JJA, SON),
  with December counted in the following year’s winter.

### Phenological retrieval error

- [`cl_pheno_power()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_power.md)
  retains each simulated acquisition with the probability that a pixel
  at a random location in the cell is observed and clear, and draws
  cloud loss from a latent Gaussian process whose correlation decays as
  `exp(-lag / tau)` over the actual intervals between acquisitions
  (argument `tau`, in days; `persistence` is deprecated). It reports the
  probability that each date is retrieved within `tolerance` days, the
  median and expected number of retained acquisitions and the reference
  dates of the curve, and offers whole-cell retention
  (`retention = "cell"`) as an alternative.
- [`cl_pheno_power()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_power.md)
  orders acquisition dates and their cloud and valid fractions together
  before simulating; unsorted input previously paired dates with the
  wrong fractions.

### Observation tables and quality layers

- [`cl_obs()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_obs.md)
  takes further named columns through `...` and keeps them aligned with
  the observations when it sorts them, and takes `percent` to state the
  scale of the fractions.
  [`cl_qa_obs()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_qa_obs.md)
  and
  [`cl_items_to_obs()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_items_to_obs.md)
  use this, so that identifiers, times and valid shares stay with their
  observations when several sensors are read together.
- [`cl_qa_decode()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_qa_decode.md)
  treats categorical classes that are neither cloud, cloud shadow, snow
  nor listed as clear as invalid: Sentinel-2 `SCL` class 1 (saturated or
  defective) is invalid, and class 2 (topographic cast shadow) is valid,
  cloud-free and coded `terrain_shadow`. Missing values are invalid for
  all sensors. Flags absent from a specification are never raised, so
  Landsat 4-7 decodes with the default `include_cirrus = TRUE`. Bit
  fields of several bits are supported and used for the MODIS cloud
  state and cirrus fields. `confidence = "low"` is no longer accepted,
  because the Landsat Collection 2 algorithm assigns low cloud
  confidence to almost all clear pixels.
- The MODIS driver no longer queries the Planetary Computer, which
  serves 8-day composites rather than daily acquisitions.
- `cl_search(backend = "planetary")` matches the catalogue’s platform
  names, reads Sentinel-2 tile identifiers from `s2:mgrs_tile`, and
  keeps the latest processing version of each tile; asset names are
  matched without regard to case.

### Availability statistics

- [`cl_gaps()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_gaps.md)
  closes the record at period boundaries with virtual observations on
  the day before and the day after the period, so that edge gaps are
  measured like interior ones, and reports the number of distinct usable
  dates as `n_clear_dates` (formerly `n_clear_obs`, which in
  [`cl_clear_obs()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_obs.md)
  counts usable acquisitions).
- [`cl_seasonality()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_seasonality.md)
  reports fits in which usable and unusable acquisitions are separated
  by day of year, flagged `separated = TRUE`, instead of returning `NA`
  for the most seasonal cells.
- `cl_clear_prob(model = "clustered")` returns the probability that an
  observation is usable at the new argument `threshold`; its
  documentation no longer describes the independent model as an upper
  bound.
- [`cl_stats_merge()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_stats_merge.md)
  returns `NA`, with a warning, for gap statistics, counts of distinct
  dates and phenological errors, which cannot be combined from
  summaries, and for combinations with missing values or sample sizes.
- [`cl_synergy()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_synergy.md)
  computes the effective revisit from the days of each period inside the
  requested window.
  [`cl_feasibility()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_feasibility.md)
  closes gaps at the window boundaries as
  [`cl_gaps()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_gaps.md)
  does.
- Usability thresholds outside \[0, 1\] are rejected, and acquisitions
  without a cloud fraction are left out of persistence and seasonality
  fits.

### Evaluation and grids

- [`cl_roc()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_roc.md)
  computes the area under the curve exactly from ranks;
  [`cl_validate()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_validate.md)
  computes the Matthews correlation without integer overflow;
  [`cl_confusion()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_confusion.md)
  compares logical masks with 0/1 references;
  [`cl_compare()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_compare.md)
  resamples pixels or blocks with replacement and keeps every copy, and
  leaves out missing pixels.
- [`cl_agreement()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_agreement.md)
  and
  [`cl_disagreement()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_disagreement.md)
  threshold a mask set without a class layer at its own threshold;
  strata without a label are left out.
- [`cl_grid()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_grid.md)
  accepts only EPSG:6933, the projection its cell coordinates are
  computed in, and stops when the grid would exceed the range of integer
  cell identifiers;
  [`cl_grid_cells()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_grid_cells.md)
  reports the area inside the projection’s domain for cells past the
  poles or the antimeridian.
- [`cl_scale()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_scale.md)
  keeps the reflectance of a `cl_scene` in its raster or list form.
- The scene explorer
  ([`cl_explore()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_explore.md))
  no longer shows cloud-method and threshold controls that had no
  effect.

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
