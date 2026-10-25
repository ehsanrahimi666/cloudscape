# Agreement among several masks

Agreement among several masks

## Usage

``` r
cl_agreement(masks)
```

## Arguments

- masks:

  Named list of `cl_maskset` objects or 0/1 matrices.

## Value

A list with `agreement` (fraction of methods calling cloud), `consensus`
(majority mask), `entropy` (binary entropy of the vote) and `unanimous`
(logical matrix).

## Examples

``` r
a <- matrix(c(1,1,0,0), 2, 2); b <- matrix(c(1,0,0,0), 2, 2)
cl_agreement(list(a = a, b = b))$agreement
#>      [,1] [,2]
#> [1,]  1.0    0
#> [2,]  0.5    0
```
