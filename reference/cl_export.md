# Export cloudscape objects

Export cloudscape objects

## Usage

``` r
cl_export(x, file, format = c("auto", "csv", "rds", "geojson", "tif"))
```

## Arguments

- x:

  A `cl_stats`, `cl_maskset` or `cl_obs`.

- file:

  Output path.

- format:

  Output format; `"auto"` infers from the extension.

## Value

The output path, invisibly.
