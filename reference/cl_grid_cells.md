# Cell identifiers, centroids and areas

Cells are numbered row-major from the top-left, matching raster
convention. Because the grid is equal-area, every cell has an area of
exactly `res^2` square metres regardless of latitude; this is the
property that removes the latitude bias present in per-scene statistics.

## Usage

``` r
cl_grid_cells(grid, cells = NULL)
```

## Arguments

- grid:

  A `cl_grid`.

- cells:

  Optional integer vector of cell ids; defaults to all cells. Supplying
  ids avoids materialising a global table.

## Value

A data frame with `cell`, `row`, `col`, `x`, `y`, `lon`, `lat`,
`area_km2`.
