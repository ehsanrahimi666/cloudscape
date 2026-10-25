# Construct a cloud/shadow mask set

Keeping probability and class in one object with the threshold and
method recorded means a mask can always be re-thresholded without
recomputation, and that comparisons between methods carry their own
provenance.

## Usage

``` r
cl_maskset(probability, class = NULL, shadow = NULL, method = NA_character_,
  threshold = NA_real_, manifest = NULL, ...)
```

## Arguments

- probability:

  `SpatRaster` or numeric matrix of cloud probability in \\0, 1\\.

- class:

  Optional integer `SpatRaster`/matrix of class codes. See
  [`cl_classes`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_classes.md)
  for the coding.

- shadow:

  Optional shadow probability layer.

- method:

  Name of the generating algorithm.

- threshold:

  Probability threshold used to derive `class`.

- manifest:

  A `cl_manifest`.

- ...:

  Additional algorithm parameters, recorded verbatim.

## Value

An object of class `cl_maskset`.
