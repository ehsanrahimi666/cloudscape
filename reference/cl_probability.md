# Compute cloud probability

Compute cloud probability

## Usage

``` r
cl_probability(x, method = "threshold", sensor = NULL, geom = NULL,
  threshold = 0.5, buffer = 0, ...)
```

## Arguments

- x:

  A `cl_scene`, or a named list of reflectance matrices.

- method:

  Method name; see
  [`cl_methods`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_methods.md).

- sensor:

  Sensor id, required when `x` is a plain list.

- geom:

  Optional list with `sun_zenith`, `sun_azimuth`, `view_zenith`,
  `view_azimuth`.

- threshold:

  Probability threshold used to derive the class layer.

- buffer:

  Dilate the resulting cloud mask by this many pixels. Cloud masks
  systematically under-detect at edges, so a small buffer is standard
  practice; the default of 0 leaves that decision explicit.

- ...:

  Passed to the method.

## Value

A `cl_maskset`.

## Examples

``` r
s <- cl_simulate(64, 64, coverage = 0.3, seed = 1,
                 background = list(blue = matrix(0.08, 64, 64),
                                   green = matrix(0.09, 64, 64),
                                   red = matrix(0.07, 64, 64),
                                   nir = matrix(0.35, 64, 64),
                                   swir16 = matrix(0.22, 64, 64)))
m <- cl_probability(s$bands, method = "threshold", sensor = "sentinel-2-msi")
round(mean(m$class), 2)
#> [1] 0.26
```
