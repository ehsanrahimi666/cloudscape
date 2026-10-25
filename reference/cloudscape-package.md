# cloudscape: Clear-Observation Availability and Cloud Analysis for Optical Satellite Image Time Series

A multi-sensor framework that turns cloud statistics into
decision-relevant measures of whether an optical time-series study is
feasible at a given location. Statistics are aggregated onto an
equal-area analysis grid rather than onto sensor footprints, removing
the latitude bias that affects per-scene counts and making Landsat and
Sentinel-2 directly comparable.

## Where to start

- [`cl_grid`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_grid.md)
  defines the equal-area analysis grid.

- [`cl_search`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_search.md)
  queries a catalogue;
  [`cl_items_to_obs`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_items_to_obs.md)
  maps results onto the grid.

- [`cl_clear_obs`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_obs.md),
  [`cl_gaps`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_gaps.md)
  and
  [`cl_seasonality`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_seasonality.md)
  summarise availability.

- [`cl_persistence`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_persistence.md)
  measures cloud autocorrelation.

- [`cl_pheno_power`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_power.md)
  converts an acquisition pattern into phenological retrieval error in
  days.

- [`cl_probability`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_probability.md)
  and
  [`cl_shadow`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_shadow.md)
  detect cloud and cloud shadow.

- [`cl_simulate`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_simulate.md)
  and
  [`cl_compare`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_compare.md)
  benchmark detectors against known truth.

## Author

Ehsan Rahimi <ehsanrahimi666@gmail.com> and Chuleui Jung
