# Extract a band by standardised name

Extract a band by standardised name

## Usage

``` r
cl_band(x, band, required = TRUE)
```

## Arguments

- x:

  A `cl_scene`.

- band:

  Standardised band name, e.g. `"nir"`.

- required:

  Error if the band is absent.

## Value

A `SpatRaster` layer, or `NULL`.
