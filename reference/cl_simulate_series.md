# Simulate a contaminated time series

Cloud occurrence is temporally autocorrelated: a cloudy day is followed
by a cloudy day more often than chance. Benchmarks built on independent
draws therefore flatter any gap-filling or compositing method, because
independent cloud almost never produces the long runs that break real
time series. This function generates cloud occurrence from a two-state
Markov chain whose persistence is set explicitly.

## Usage

``` r
cl_simulate_series(dates, p_cloud = 0.5, persistence = 0.35, seed = NULL)
```

## Arguments

- dates:

  Acquisition dates.

- p_cloud:

  Marginal probability of a cloudy acquisition.

- persistence:

  Lag-1 autocorrelation of the cloudy/clear sequence, in \\0, 1). 0
  gives independent draws; 0.35 is a reasonable default for acquisitions
  spaced a few days apart. Parameterising by correlation rather than by
  a transition multiplier keeps the marginal probability exact at every
  value, which a multiplier does not: multipliers must be clamped at
  high cloud fractions, and the clamped chain then mixes so slowly that
  a one-year series never leaves its initial state.

- seed:

  Random seed.

## Value

A data frame with `date`, `cloudy` and `cloud_fraction`.

## Examples

``` r
d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
ts <- cl_simulate_series(d, p_cloud = 0.6, persistence = 0.35, seed = 1)
mean(ts$cloudy)
#> [1] 0.630137
```
