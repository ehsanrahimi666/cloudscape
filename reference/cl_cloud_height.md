# Estimate cloud-top height from thermal brightness temperature

Uses the classical moist-adiabatic approach: the temperature difference
between the cloud and the surrounding clear sky, divided by an assumed
lapse rate, gives a height. The result is bracketed by physically
plausible limits because the lapse rate is an assumption, not a
measurement, and because thermal contrast collapses over cold surfaces.

Sensors without a thermal band return the supplied `default_range`
instead, which is the honest answer: for Sentinel-2 the cloud-top height
genuinely cannot be retrieved from the imagery alone and must be
searched over.

## Usage

``` r
cl_cloud_height(bt = NULL, cloud, clear = NULL, lapse_rate = 0.0065, limits
  = c(200, 12000), default_range = c(200, 12000))
```

## Arguments

- bt:

  Brightness temperature matrix in Kelvin, or `NULL`.

- cloud:

  Logical cloud matrix.

- clear:

  Optional logical matrix of confidently clear pixels; defaults to the
  complement of `cloud`.

- lapse_rate:

  Environmental lapse rate in K/m.

- limits:

  Physically plausible height range in metres.

- default_range:

  Height range returned when no thermal band exists.

## Value

A list with `height` (best estimate, `NA` if unavailable) and `range` (a
length-2 search interval in metres).
