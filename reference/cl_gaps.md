# Cloud-gap statistics

Mean cloud cover is a poor summary of whether a time series is workable.
What breaks a phenology retrieval is not the average, it is the longest
stretch with no usable observation. `cl_gaps()` reports that stretch,
its distribution, and the return period of gaps exceeding a stated
length.

Gaps at the boundaries of the analysis window are included by default,
because a cell whose first clear observation arrives in April has
genuinely lost the spring green-up regardless of how many observations
follow.

## Usage

``` r
cl_gaps(obs, threshold = 0.2, by = c("year", "all", "season"), include_edges
  = TRUE, critical = 30)
```

## Arguments

- obs:

  A `cl_obs` table.

- threshold:

  Maximum cloud fraction for a usable observation.

- by:

  Period granularity for reporting.

- include_edges:

  Count the intervals from period start to first clear observation and
  from last clear observation to period end.

- critical:

  Gap length in days whose exceedance frequency is reported.

## Value

A `cl_stats` table with `max_gap_days` and `mean_gap_days`, carrying an
attribute `exceedance` giving the fraction of periods per cell in which
`critical` was exceeded.
