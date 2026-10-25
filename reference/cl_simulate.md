# Simulate clouds and cloud shadows

Generates a synthetic cloud field with controllable coverage, size, edge
softness and opacity, casts a geometrically consistent shadow, and
optionally composites both onto a background reflectance scene.

Opacity is the key difficulty control. Fully opaque cloud is easy for
every method; the discrimination between algorithms happens between
roughly 0.2 and 0.6 opacity, which is where thin cirrus and cloud edges
live and where published masks disagree most.

## Usage

``` r
cl_simulate(nrow = 256, ncol = 256, background = NULL, coverage = 0.25, size
  = 0.15, opacity = c(0.3, 1), edge_softness = 3, height = 2000, res = 30,
  sun_zenith = 40, sun_azimuth = 150, view_zenith = 0, view_azimuth = 0,
  shadow_darkening = 0.45, cloud_reflectance = 0.8, noise = 0.005, seed =
  NULL)
```

## Arguments

- nrow:

  Scene dimensions in pixels. Ignored if `background` is given.

- ncol:

  Scene dimensions in pixels. Ignored if `background` is given.

- background:

  Optional named list or 3-D array of clear reflectance bands to
  composite onto. Band names should be standardised.

- coverage:

  Target cloud fraction in \\0, 1\\.

- size:

  Characteristic cloud size as a fraction of scene width; smaller values
  give more, smaller clouds.

- opacity:

  Cloud opacity in \\0, 1\\; 1 is fully opaque. May be a length-2 vector
  giving a range, sampled per cloud object.

- edge_softness:

  Width of the semi-transparent cloud edge, in pixels.

- height:

  Cloud-top height in metres.

- res:

  Pixel size in metres.

- sun_zenith:

  Geometry in degrees.

- sun_azimuth:

  Geometry in degrees.

- view_zenith:

  Geometry in degrees.

- view_azimuth:

  Geometry in degrees.

- shadow_darkening:

  Multiplicative reflectance factor inside shadow.

- cloud_reflectance:

  Reflectance of fully opaque cloud.

- noise:

  Standard deviation of additive Gaussian sensor noise.

- seed:

  Random seed.

## Value

A list with `cloud` (0/1 truth), `opacity` (continuous), `shadow` (0/1
truth), `truth` (class codes from
[`cl_classes`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_classes.md)),
`bands` (list of contaminated reflectance matrices, when `background`
was supplied) and `params`.

## Examples

``` r
s <- cl_simulate(120, 120, coverage = 0.3, opacity = c(0.4, 1), seed = 42)
round(mean(s$cloud), 2)
#> [1] 0.3
sum(s$shadow) > 0
#> [1] TRUE
```
