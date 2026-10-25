# Construct a scene

A `cl_scene` bundles everything an algorithm needs for one acquisition.
Reflectance is held as a
[`terra::SpatRaster`](https://rspatial.github.io/terra/reference/SpatRaster-class.html),
which is itself lazy: pixels stay on disk until a computation forces
them into memory. Attaching a DEM, solar geometry or QA layer never
triggers a read.

## Usage

``` r
cl_scene(reflectance = NULL, sensor, datetime = NULL, solar_geom = NULL,
  view_geom = NULL, dem = NULL, qa = NULL, masks = list(), footprint = NULL,
  id = NULL, manifest = NULL, ...)
```

## Arguments

- reflectance:

  A `SpatRaster` with layers named using standardised band names, or
  `NULL`.

- sensor:

  Sensor id or `cl_sensor` driver.

- datetime:

  Acquisition time (`POSIXct` or something coercible).

- solar_geom:

  List with `zenith` and `azimuth` in degrees; either scalars
  (scene-mean) or `SpatRaster` layers (per-pixel).

- view_geom:

  List with `zenith` and `azimuth` in degrees.

- dem:

  Optional elevation `SpatRaster` aligned to `reflectance`.

- qa:

  Optional QA `SpatRaster`.

- masks:

  Named list of `cl_maskset` objects.

- footprint:

  Optional lon/lat vertex matrix or `sf` geometry.

- id:

  Scene identifier.

- manifest:

  A `cl_manifest`.

- ...:

  Additional metadata stored verbatim.

## Value

An object of class `cl_scene`.
