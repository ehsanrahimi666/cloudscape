# Project longitude/latitude to and from EASE-Grid 2.0 metres

Closed-form cylindrical equal-area projection on the WGS84 ellipsoid.
These are provided directly rather than through PROJ so that the
analysis grid, and the tests that verify it, work without a geospatial
toolchain.

## Usage

``` r
cl_project(lon, lat, lat_ts = 30)
cl_unproject(x, y, lat_ts = 30)
```

## Arguments

- lon:

  Longitude and latitude in degrees.

- lat:

  Longitude and latitude in degrees.

- x:

  Projected coordinates in metres.

- y:

  Projected coordinates in metres.

- lat_ts:

  Standard parallel in degrees. 30 gives EPSG:6933.

## Value

A two-column matrix with columns `x`/`y` or `lon`/`lat`.

## Examples

``` r
cl_project(c(0, 90), c(0, 45))
#>            x       y
#> [1,]       0       0
#> [2,] 8683765 5180102
cl_unproject(cl_project(10, 50)[, 1], cl_project(10, 50)[, 2])
#>   lon lat
#> x  10  50
```
