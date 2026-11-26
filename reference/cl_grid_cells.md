# Cell identifiers, centroids and areas

Cells are numbered row-major from the top-left, matching raster
convention. Because the grid is equal-area, every cell has an area of
`res^2` square metres regardless of latitude. Cells of the outermost
rows and columns of a global grid can extend past the poles or the
antimeridian, where the projection has no surface; their `area_km2` is
the part inside the projection's domain.

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
