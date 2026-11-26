# Seasonal clear-sky model

Fits a harmonic logistic model of clear-sky probability against day of
year for each cell, and reports the phase of the clear-sky maximum. The
practical output is a best-acquisition-window map: the contiguous
stretch of the year during which a cell is most likely to be observable.

## Usage

``` r
cl_seasonality(obs, threshold = 0.2, harmonics = 1L, window_days = 60,
  min_obs = 12, coverage = TRUE)
```

## Arguments

- obs:

  A `cl_obs` table.

- threshold:

  Usability threshold, see
  [`cl_clear_obs`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_obs.md).

- harmonics:

  Number of annual harmonics (1 or 2).

- window_days:

  Length of the reported best window.

- min_obs:

  Minimum observations per cell required to attempt a fit.

- coverage:

  Take the valid share of the cell into account, see
  [`cl_clear_obs`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_obs.md).
  When usable and unusable acquisitions are separated, or nearly so, by
  day of year, the maximum-likelihood estimates diverge and the fitted
  probabilities approach 0 and 1. Such fits are reported, flagged with
  `separated = TRUE`, rather than dropped, because they belong to the
  most seasonal cells. Their fitted probabilities overstate how certain
  the seasonal switch is, but their peak and window remain informative.

## Value

A data frame with one row per cell: `amplitude`, `peak_doy`,
`p_clear_peak`, `p_clear_trough`, `window_start`, `window_end`, `n`,
`converged` and `separated`. Cells with fewer than `min_obs`
acquisitions, or with only usable or only unusable ones, have `NA`
estimates.
