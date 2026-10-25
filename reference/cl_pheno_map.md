# Map phenological retrieval error across grid cells

Applies
[`cl_pheno_power`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_power.md)
cell by cell using the actual acquisition dates and cloud fractions
recorded for each cell, turning an observation table into a map of
expected phenological uncertainty.

## Usage

``` r
cl_pheno_map(obs, year = NULL, n_sim = 50L, ...)
```

## Arguments

- obs:

  A `cl_obs` table.

- year:

  Year to analyse; defaults to the most frequent year present.

- n_sim:

  Replicates per cell.

- ...:

  Passed to
  [`cl_pheno_power`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_power.md).

## Value

A `cl_stats` table with metric `sos_error_days`, carrying a `details`
attribute with the full per-cell summaries.
