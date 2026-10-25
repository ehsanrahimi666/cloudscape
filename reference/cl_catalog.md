# Configure or inspect a catalogue backend

Configure or inspect a catalogue backend

## Usage

``` r
cl_catalog(backend = NULL)
```

## Arguments

- backend:

  One of `"element84"`, `"planetary"`, `"cdse"`.

## Value

A list describing the backend.

## Examples

``` r
cl_catalog("element84")$url
#> [1] "https://earth-search.aws.element84.com/v1"
```
