# Require a suggested package

cloudscape keeps its hard dependency surface small: the statistical core
(availability, gaps, seasonality, phenology, evaluation, simulation)
runs on base R alone, while raster and network functionality is gated
behind suggested packages. This helper produces a single actionable
error rather than an opaque failure deep in a call stack.

## Usage

``` r
cl_require(pkg, reason = NULL)
```

## Arguments

- pkg:

  Package name(s).

- reason:

  Short description of what the package is needed for.

## Value

`TRUE` invisibly if all packages are available; otherwise an error.
