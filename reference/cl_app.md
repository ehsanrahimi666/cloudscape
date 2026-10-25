# Launch the interactive scene explorer

Live imagery browsing needs a server: asset URLs from most catalogues
are signed and expire, and masks are computed on demand. This is
therefore a Shiny application rather than a static file.

## Usage

``` r
cl_app(stats = NULL, ...)
```

## Arguments

- stats:

  Optional `cl_stats` to seed the map.

- ...:

  Passed to
  [`shiny::runApp()`](https://rdrr.io/pkg/shiny/man/runApp.html).

## Value

Invisibly `NULL`.
