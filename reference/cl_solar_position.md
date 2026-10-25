# Solar position for a location and time

A compact solar position algorithm, accurate to a few hundredths of a
degree over the satellite era, used when a scene lacks per-pixel angle
grids.

## Usage

``` r
cl_solar_position(datetime, lon, lat)
```

## Arguments

- datetime:

  `POSIXct` in UTC.

- lon:

  Coordinates in degrees.

- lat:

  Coordinates in degrees.

## Value

A data frame with `zenith` and `azimuth` in degrees.

## Examples

``` r
cl_solar_position(as.POSIXct("2023-06-21 12:00:00", tz = "UTC"), 0, 51.5)
#>     zenith  azimuth
#> 1 28.06653 179.1423
```
