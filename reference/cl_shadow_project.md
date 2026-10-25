# Project a cloud mask to candidate shadow locations

Sweeps a range of plausible cloud-top heights, displaces the cloud mask
by the corresponding ground offset at each height, and returns either
the height that best matches a supplied darkness layer or the union of
all candidate positions.

The similarity criterion follows the standard formulation: for each
height, score the fraction of projected pixels that are actually dark,
and take the height maximising that fraction. When no darkness layer is
supplied the function returns a conservative union mask, which is
appropriate for screening but will over-mask.

## Usage

``` r
cl_shadow_project(cloud, darkness = NULL, res = 30, sun_zenith = 40,
  sun_azimuth = 180, view_zenith = 0, view_azimuth = 0, heights = seq(200,
  12000, by = 200), dark_threshold = 0.12)
```

## Arguments

- cloud:

  Logical or 0/1 matrix of cloud pixels.

- darkness:

  Optional numeric matrix in \\0, 1\\ where high values indicate
  potential shadow (dark in NIR/SWIR). Required for height search.

- res:

  Pixel size in metres.

- sun_zenith:

  Illumination geometry in degrees.

- sun_azimuth:

  Illumination geometry in degrees.

- view_zenith:

  Viewing geometry in degrees.

- view_azimuth:

  Viewing geometry in degrees.

- heights:

  Candidate cloud-top heights in metres.

- dark_threshold:

  Relative darkening above which a pixel counts as shadowed when scoring
  a candidate height. 0.12 means the pixel is at least 12 percent darker
  than the clear-sky reference.

## Value

A list with `shadow` (0/1 matrix), `height` (best height in metres, `NA`
when no darkness layer was supplied), `score` (matching fraction),
`retained` (fraction of the projected shadow still inside the window at
the selected height), `truncated` (logical; `TRUE` when no candidate
height keeps at least half its shadow inside the window, in which case
the height is not identifiable), `window_m`, `required_m`,
`resolvable_m` (the largest cloud-top height this window can resolve),
and `profile` (a data frame of score and retention against height).

## Examples

``` r
cloud <- matrix(0, 40, 40); cloud[18:22, 18:22] <- 1
dark  <- matrix(0, 40, 40); dark[8:12, 18:22] <- 1   # shadow 10 cells north
r <- cl_shadow_project(cloud, dark, res = 100, sun_zenith = 45,
                       sun_azimuth = 180, heights = seq(200, 2000, 100))
r$height
#> [1] 1000
```
