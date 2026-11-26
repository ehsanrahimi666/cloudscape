# Compare methods with uncertainty

Paired comparison of two or more masks against a common reference.
Reports bootstrap confidence intervals on overall accuracy for each
method, and McNemar's test for each pair, so that a difference is only
claimed when the paired evidence supports it. McNemar's test treats
pixels as independent, so its p-values are optimistic for spatially
autocorrelated masks; the block bootstrap intervals are the more
conservative evidence.

## Usage

``` r
cl_compare(preds, truth, n_boot = 500L, conf = 0.95, block = NULL)
```

## Arguments

- preds:

  Named list of predicted masks.

- truth:

  Reference mask.

- n_boot:

  Bootstrap replicates.

- conf:

  Confidence level.

- block:

  Optional vector of block ids, one per pixel, for a block bootstrap
  that resamples whole blocks with replacement. Cloud masks are
  spatially autocorrelated, so a pixel-wise bootstrap understates
  uncertainty; blocks such as tiles or scenes account for that
  dependence at their scale. Pixels missing in the reference, a
  prediction or `block` are left out.

## Value

A list with `summary` (per-method accuracy and interval) and `pairwise`
(McNemar statistics and p-values).

## Examples

``` r
set.seed(3)
truth <- matrix(rbinom(1000, 1, .35), 25, 40)
a <- truth; a[sample(1000, 60)] <- 1 - a[sample(1000, 60)]
b <- truth; b[sample(1000, 120)] <- 1 - b[sample(1000, 120)]
cl_compare(list(good = a, worse = b), truth, n_boot = 200)$summary
#>   method accuracy    lower upper
#> 1   good    0.969 0.957975 0.980
#> 2  worse    0.933 0.919975 0.948
```
