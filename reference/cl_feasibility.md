# Sampling design feasibility

Given a clear-sky probability and an acquisition cadence, reports the
probability of obtaining at least `n_required` usable observations
within a window, and the probability that no gap exceeds `max_gap`.

## Usage

``` r
cl_feasibility(p_clear, n_acquisitions, n_required, window_days = 365,
  max_gap = NULL, n_sim = 2000)
```

## Arguments

- p_clear:

  Per-acquisition probability that the cell is usable.

- n_acquisitions:

  Number of acquisition opportunities in the window.

- n_required:

  Minimum usable observations needed.

- window_days:

  Length of the window in days.

- max_gap:

  Maximum tolerable gap in days, or `NULL` to skip.

- n_sim:

  Monte Carlo replicates for the gap calculation.

## Value

A list with `p_sufficient`, `expected_obs`, and, when `max_gap` is
given, `p_gap_ok`.

## Examples

``` r
cl_feasibility(p_clear = 0.35, n_acquisitions = 36, n_required = 12,
               window_days = 365, max_gap = 45)
#> $expected_obs
#> [1] 12.6
#> 
#> $p_sufficient
#> [1] 0.6436908
#> 
#> $p_gap_ok
#> [1] 0.04
#> 
#> $n_sim
#> [1] 2000
#> 
```
