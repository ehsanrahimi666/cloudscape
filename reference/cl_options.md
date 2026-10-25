# Get or set package options

`cl_options()` is the single configuration entry point for cloudscape.
Called with no arguments it returns the full option list. Called with
named arguments it sets them and returns the previous values invisibly,
so it can be used with \[base::on.exit()\] to make temporary changes.

## Usage

``` r
cl_options(...)
```

## Arguments

- ...:

  Named options to set. Supported names:

  `catalog`

  :   Default STAC backend, one of `"element84"`, `"planetary"`,
      `"cdse"`.

  `grid_res`

  :   Default analysis grid resolution in metres.

  `grid_crs`

  :   EPSG code of the equal-area analysis CRS. Defaults to 6933
      (EASE-Grid 2.0 global).

  `chunk_pixels`

  :   Target pixels per processing block.

  `workers`

  :   Number of parallel workers.

  `cache_dir`

  :   Directory for downloaded assets and harvest state.

  `timeout`

  :   HTTP timeout in seconds.

  `max_page`

  :   Maximum STAC items requested per page.

  `verbose`

  :   Emit progress messages.

## Value

A named list of options. When setting, the previous values are returned
invisibly.

## Examples

``` r
old <- cl_options(verbose = FALSE)
cl_options()$verbose
#> [1] FALSE
cl_options(old)
```
