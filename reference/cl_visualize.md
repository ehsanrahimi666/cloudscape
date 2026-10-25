# Quick look at a mask or scene

Quick look at a mask or scene

## Usage

``` r
cl_visualize(x, what = c("probability", "class", "shadow"), ...)
```

## Arguments

- x:

  A `cl_maskset`, `cl_scene` or matrix.

- what:

  For a maskset, `"probability"`, `"class"` or `"shadow"`.

- ...:

  Passed to \[graphics::image()\].

## Value

Invisibly `x`.
