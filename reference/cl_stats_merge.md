# Combine statistics tables

Merges rows describing the same cell, period, sensor and metric, using
the combination rule declared for each metric in
[`cl_metrics`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_metrics.md):
counts add, fractions and rates combine as sample-size-weighted means,
and maximum gap takes the maximum.

This is for combining *disjoint* evidence, such as separate years,
sensors or spatial partitions. It cannot repair double counting: if the
same acquisition was aggregated into two inputs, summing the counts will
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
