# Pairwise disagreement between masks

Pairwise disagreement between masks

## Usage

``` r
cl_disagreement(masks, strata = NULL)
```

## Arguments

- masks:

  Named list of masks.

- strata:

  Optional factor or matrix of stratum labels, for example a land-cover
  or snow layer, used to report where methods diverge.

## Value

A list with `pairwise` (a data frame of agreement, Jaccard and
commission/omission relative to each other) and, when `strata` is given,
`by_stratum`.
