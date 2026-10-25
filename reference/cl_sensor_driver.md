# Construct a sensor driver

A sensor driver is the single point of sensor-specific knowledge in
cloudscape. Algorithms address bands by standardised names (`blue`,
`nir`, `swir16`, `cirrus`, `tir1`, ...) and the driver translates those
into the asset names a particular catalogue uses. Everything downstream
is therefore sensor-agnostic.

## Usage

``` r
cl_sensor_driver(id, name, bands, resolution = NULL, platforms = NULL,
  footprint = "none", revisit = NA_real_, qa = NULL, scale = 1, offset = 0,
  collections = list(), cloud_property = "eo:cloud_cover", has_thermal =
  FALSE, has_cirrus = FALSE, notes = NULL)
```

## Arguments

- id:

  Short identifier, e.g. `"landsat-8-9-oli"`.

- name:

  Human-readable name.

- bands:

  Named character vector mapping standardised band names to the asset or
  layer names used by this sensor.

- resolution:

  Named numeric vector of native resolutions in metres, using the same
  standardised band names.

- platforms:

  `data.frame` with columns `platform`, `start`, `end` giving the
  operational period of each satellite in the constellation. `end` may
  be `NA` for currently active platforms. Used by
  [`cl_synergy`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_synergy.md)
  to compute time-varying revisit.

- footprint:

  Footprint geometry type: `"wrs2"`, `"mgrs"`, `"sinusoidal"`, `"scene"`
  or `"none"`.

- revisit:

  Nominal revisit interval in days for a single platform.

- qa:

  Optional QA specification created by
  [`cl_qa_spec`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_qa_spec.md).

- scale:

  Linear rescaling from stored integers to reflectance.

- offset:

  Linear rescaling from stored integers to reflectance.

- collections:

  Named list mapping catalogue backends to collection ids.

- cloud_property:

  Name of the scene-level cloud-cover property in catalogue metadata.

- has_thermal:

  Logical capability flags. Algorithms that require these bands check
  the flags and degrade gracefully.

- has_cirrus:

  Logical capability flags. Algorithms that require these bands check
  the flags and degrade gracefully.

- notes:

  Free text recorded in manifests.

## Value

An object of class `cl_sensor`.

## Examples

``` r
drv <- cl_sensor("landsat-8-9-oli")
drv$bands[["cirrus"]]
#> [1] "cirrus"
```
