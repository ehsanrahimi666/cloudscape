# Define an equal-area analysis grid

Define an equal-area analysis grid

## Usage

``` r
cl_grid(res = NULL, crs = NULL, extent = "global")
```

## Arguments

- res:

  Cell size in metres. Common choices are 100000 for global overviews,
  25000 for continental analysis and 5000 for regional work.

- crs:

  EPSG code of the equal-area CRS. Only 6933 is supported by the
  built-in closed-form projection; other codes require `sf`.

- extent:

  Either `"global"` or a numeric vector `c(xmin, ymin, xmax, ymax)` in
  **degrees**.

## Value

An object of class `cl_grid`.

## Examples

``` r
g <- cl_grid(res = 100000)
g
#> <cl_grid> EPSG:6933
#>   resolution : 1e+05 m (cell area 10,000 km2)
#>   dimensions : 148 rows x 348 cols = 51,504 cells
#>   extent     : -180, -90, 180, 90 (degrees)
nrow(cl_grid_cells(g)) > 0
#> [1] TRUE
```
