# Build an observation table

Build an observation table

## Usage

``` r
cl_obs(cell, date, cloud_fraction, sensor = NA_character_, platform =
  NA_character_, tier = "metadata", shadow_fraction = NA_real_,
  snow_fraction = NA_real_)
```

## Arguments

- cell:

  Integer grid cell ids.

- date:

  Acquisition dates.

- cloud_fraction:

  Cloud fraction in \\0, 1\\ for the cell.

- sensor:

  Sensor ids.

- platform:

  Optional platform names.

- tier:

  Which evidence tier the cloud fractions came from: `"metadata"`
  (scene-level catalogue property), `"qa"` (aggregated quality layer) or
  `"mask"` (computed mask).

- shadow_fraction:

  Optional additional fractions.

- snow_fraction:

  Optional additional fractions.

## Value

An object of class `cl_obs`, inheriting from `data.frame`.
