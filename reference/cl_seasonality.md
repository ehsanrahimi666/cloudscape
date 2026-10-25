# Seasonal clear-sky model

Fits a harmonic logistic model of clear-sky probability against day of
year for each cell, and reports the phase of the clear-sky maximum. The
practical output is a best-acquisition-window map: the contiguous
stretch of the year during which a cell is most likely to be observable.

## Usage

``` r
cl_seasonality(obs, threshold = 0.2, harmonics = 1L, window_days = 60,
  min_obs = 12)
```

## Arguments

- obs:

  A `cl_obs` table.

- threshold:

  Maximum cloud fraction for a usable observation.

- harmonics:

  Number of annual harmonics (1 or 2).

- window_days:

  Length of the reported best window.

- min_obs:

  Minimum observations per cell required to attempt a fit.

## Value

A data frame with one row per cell: `amplitude`, `peak_doy`,
`p_clear_peak`, `p_clear_trough`, `window_start`, `window_end`, `n`, and
`converged`.
