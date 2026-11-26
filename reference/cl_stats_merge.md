# Combine statistics tables

Merges rows describing the same cell, period, sensor and metric, using
the combination rule declared for each metric in
[`cl_metrics`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_metrics.md):
counts add and fractions and probabilities combine as means weighted by
the number of observations behind each value (`n`). Gap statistics,
counts of distinct usable dates and errors of phenological dates (rule
`"none"`) cannot be recovered from summaries: a gap can span the
boundary between two inputs, observations from another input shorten it,
and two inputs can share a date. Rows of these metrics that would have
to be combined are returned as `NA` with a warning; compute them from
the combined observation table instead. A combined value is also `NA`,
with a warning, when one of its parts is missing or, for weighted means,
has no sample size.

The rules are valid for *disjoint* evidence with denominators counted in
the same unit, such as separate sensors or separate sets of acquisitions
of one cell and period. They cannot repair double counting: if the same
acquisition was aggregated into two inputs, summing the counts will
inflate them. Deduplicate at the observation level before aggregating.

## Usage

``` r
cl_stats_merge(..., grid = NULL)
```

## Arguments

- ...:

  `cl_stats` tables.

- grid:

  Optional `cl_grid` recorded on the result.

## Value

A single `cl_stats` table.

## Examples

``` r
a <- cl_stats(1:2, "n_scenes", c(10, 12), period = "2023", n = c(10, 12))
b <- cl_stats(1:2, "n_scenes", c(5, 6), period = "2023", n = c(5, 6))
cl_stats_merge(a, b)$value
#> [1] 15 18
```
