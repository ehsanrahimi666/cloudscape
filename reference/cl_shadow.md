# Detect cloud shadows

High-level entry point combining a darkness index, geometric projection
and optional thermal height constraint.

## Usage

``` r
cl_shadow(cloud, nir = NULL, swir = NULL, bt = NULL, water = NULL, res = 30,
  sun_zenith = 40, sun_azimuth = 180, view_zenith = 0, view_azimuth = 0,
  method = c("geometric", "darkness", "union"), heights = seq(200, 12000, by
  = 200), buffer = 0, dark_threshold = 0.12)
```

## Arguments

- cloud:

  Logical/0-1 cloud matrix or `SpatRaster`.

- nir:

  Reflectance matrices used to build the darkness index. NIR alone is
  workable; adding SWIR sharply reduces confusion with water.

- swir:

  Reflectance matrices used to build the darkness index. NIR alone is
  workable; adding SWIR sharply reduces confusion with water.

- bt:

  Optional brightness temperature for height estimation.

- water:

  Optional logical matrix of water pixels, excluded from shadow.

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

- method:

  `"geometric"` searches heights against a darkness layer; `"darkness"`
  thresholds the darkness index alone, ignoring geometry; `"union"`
  returns the geometric union across all heights.

- heights:

  Candidate heights in metres.

- buffer:

  Dilate the resulting shadow by this many pixels.

- dark_threshold:

  Relative darkening counted as shadow; see
  [`cl_shadow_project`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_shadow_project.md).

## Value

A `cl_maskset` with the shadow layer populated.
