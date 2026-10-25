# Construct a grid statistics table

`cl_stats` is a long-format table: one row per cell, period, sensor and
metric. Every row must declare its `unit`, its sample size `n`, and the
`denominator` the value is expressed per. The constructor validates
these against a controlled vocabulary and refuses out-of-range values.

This strictness is deliberate. A count of images summed over ten years
and then divided by ten is a mean *per year*, not a mean *per scene
footprint*; presenting one as the other produces values that are
physically impossible for the stated denominator. Encoding the
denominator in the data structure makes that class of error a validation
failure rather than a published table.

## Usage

``` r
cl_stats(cell, metric, value, period = NA_character_, sensor =
  NA_character_, n = NA_integer_, se = NA_real_, denominator = "cell-year",
  grid = NULL, manifest = NULL)
```

## Arguments

- cell:

  Integer grid cell ids.

- metric:

  Metric name; see
  [`cl_metrics`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_metrics.md).

- value:

  Numeric values.

- period:

  Character period labels, e.g. `"2023"` or `"2023-06"`.

- sensor:

  Sensor ids.

- n:

  Sample size behind each value.

- se:

  Optional standard errors.

- denominator:

  What the value is expressed per: one of `"cell"`, `"cell-year"`,
  `"cell-month"`, `"scene"`, `"pixel"`.

- grid:

  Optional `cl_grid` the cells refer to.

- manifest:

  A `cl_manifest`.

## Value

An object of class `cl_stats`, which inherits from `data.frame`.

## Examples

``` r
s <- cl_stats(cell = 1:3, metric = "cloud_fraction", value = c(.2, .5, .9),
              period = "2023", sensor = "sentinel-2-msi", n = c(40, 38, 41),
              denominator = "cell-year")
summary(s)
#>           metric     unit n_rows min median      mean max
#> 1 cloud_fraction fraction      3 0.2    0.5 0.5333333 0.9
```
