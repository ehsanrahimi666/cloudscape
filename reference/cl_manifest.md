# Create or extract a provenance manifest

Satellite archives are reprocessed. Collection 2 changed Landsat cloud
masking relative to Collection 1, and successive Sen2Cor baselines
changed the Sentinel-2 scene classification layer. A statistic computed
today may therefore differ from the same statistic computed on the same
nominal data next year. Every cloudscape object carries a manifest
recording exactly what was queried, when, and with which algorithm, so
results remain auditable.

## Usage

``` r
cl_manifest(x = NULL, ...)
```

## Arguments

- x:

  An object with a manifest, or `NULL` to build a fresh one.

- ...:

  Named fields to record.

## Value

An object of class `cl_manifest`: a named list.

## Examples

``` r
m <- cl_manifest(NULL, source = "element84", collection = "sentinel-2-l2a")
m$collection
#> [1] "sentinel-2-l2a"
```
