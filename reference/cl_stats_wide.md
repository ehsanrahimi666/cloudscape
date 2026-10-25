# Reshape statistics from long to wide

Reshape statistics from long to wide

## Usage

``` r
cl_stats_wide(x, metrics = NULL)
```

## Arguments

- x:

  A `cl_stats`.

- metrics:

  Metrics to include; defaults to all.

## Value

A data frame with one row per cell/period/sensor and one column per
metric.
