# Build an observation table

Build an observation table

## Usage

``` r
cl_obs(cell, date, cloud_fraction, sensor = NA_character_, platform =
  NA_character_, tier = "metadata", shadow_fraction = NA_real_,
  snow_fraction = NA_real_, ..., percent = NULL)
```

## Arguments

- cell:

  Integer grid cell ids.

- date:

  Acquisition dates.

- cloud_fraction:

  Cloud fraction of the cell, as a fraction in \\0, 1\\ or, with
  `percent = TRUE`, as a percentage in \\0, 100\\.

- sensor:

  Sensor ids.

- platform:

  Optional platform names.

- tier:

  Which evidence tier the cloud fractions came from: `"metadata"`
  (scene-level catalogue property), `"qa"` (aggregated quality layer) or
  `"mask"` (computed mask).

- shadow_fraction:

  Optional additional fractions, on the same scale as `cloud_fraction`.

- snow_fraction:

  Optional additional fractions, on the same scale as `cloud_fraction`.

- ...:

  Further named columns, each of length one or of the length of `cell`,
  kept aligned with the observations (for example `valid_fraction` or a
  scene identifier).

- percent:

  Whether the fractions are given as percentages. With `NULL` they are
  taken as percentages, with a warning, only when a cloud fraction
  exceeds 1; a percentage series whose values never exceed 1 cannot be
  recognised and must be passed with `percent = TRUE`.

## Value

An object of class `cl_obs`, inheriting from `data.frame`, ordered by
cell and date.
