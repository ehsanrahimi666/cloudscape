# Index sensor footprints onto the analysis grid

Converts a scene or tile footprint into a set of grid cells with
weights. Two methods are available. `"centroid"` assigns a cell to a
footprint when the cell centroid falls inside it; it is unbiased in
expectation, needs no geospatial dependencies, and is accurate when
cells are much smaller than footprints (the usual case: 25 km cells
against 180 km Landsat scenes). `"area"` computes exact fractional
overlap and requires `sf`; use it when cell size approaches footprint
size.

## Usage

``` r
cl_grid_index(footprint, grid, method = c("centroid", "area"))
```

## Arguments

- footprint:

  Either a two-column matrix or data frame of polygon vertex longitudes
  and latitudes, or an `sf` object.

- grid:

  A `cl_grid`.

- method:

  `"centroid"` or `"area"`.

## Value

A data frame with columns `cell` and `weight`, where `weight` is the
fraction of the cell covered by the footprint (always 1 for
`method = "centroid"`).

## Examples

``` r
g <- cl_grid(res = 100000)
poly <- cbind(lon = c(0, 2, 2, 0, 0), lat = c(50, 50, 52, 52, 50))
head(cl_grid_index(poly, g))
#>   cell weight
#> 1 5743      1
#> 2 5744      1
#> 3 6091      1
#> 4 6092      1
```
