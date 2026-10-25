# Cast shadow from terrain

Terrain shadow is routinely confused with cloud shadow in rugged
country: both are dark, both correlate with slope aspect, and neither
Fmask, Sen2Cor's scene classification nor single-date neural masks
separate them explicitly. Computing terrain shadow from a DEM lets
[`cl_shadow`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_shadow.md)
exclude it, and lets
[`cl_reliability`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_reliability.md)
flag where the distinction is hard.

Implemented by marching along the solar ray from each pixel and testing
whether any upstream terrain rises above the ray.

## Usage

``` r
cl_terrain_shadow(dem, sun_zenith, sun_azimuth, res = 30, max_distance =
  20000)
```

## Arguments

- dem:

  Elevation matrix in metres.

- sun_zenith:

  Illumination geometry in degrees.

- sun_azimuth:

  Illumination geometry in degrees.

- res:

  Pixel size in metres.

- max_distance:

  Maximum ray length in metres.

## Value

A 0/1 matrix, 1 where terrain blocks direct illumination.

## Examples

``` r
dem <- matrix(0, 30, 30); dem[, 20:30] <- 500   # a ridge on the east side
ts <- cl_terrain_shadow(dem, sun_zenith = 70, sun_azimuth = 90, res = 30)
sum(ts) > 0
#> [1] TRUE
```
