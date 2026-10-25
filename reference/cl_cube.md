# Construct a lazy scene collection

A `cl_cube` never holds pixels. It holds an index of scenes plus a
template describing the target geometry, and materialises blocks on
demand. This is what allows a decade of imagery to be summarised without
exhausting memory.

## Usage

``` r
cl_cube(scenes, template = NULL, grid = NULL, manifest = NULL)
```

## Arguments

- scenes:

  A list of `cl_scene` objects, or a data frame index with at least the
  columns `id`, `datetime`, `sensor` and `href`.

- template:

  Optional `SpatRaster` defining target grid, extent and CRS.

- grid:

  Optional `cl_grid` for statistical aggregation.

- manifest:

  A `cl_manifest`.

## Value

An object of class `cl_cube`.
