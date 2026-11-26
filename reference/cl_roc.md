# ROC curve and area under it

The curve is tabulated at `n_thresh` thresholds between 0 and 1, an
observation being called positive when its probability is at least the
threshold. The area under the curve is computed exactly from the ranks
of the probabilities (the Mann-Whitney statistic, with ties counted as
one half), so it does not depend on the thresholds tabulated and is
correct for binary or saturating predictions.

## Usage

``` r
cl_roc(prob, truth, n_thresh = 101)
```

## Arguments

- prob:

  Predicted probabilities in \\0, 1\\.

- truth:

  Binary reference (1 = positive).

- n_thresh:

  Number of thresholds to tabulate.

## Value

A data frame of `threshold`, `fpr`, `tpr`, `precision`, with an `auc`
attribute.

## Examples

``` r
set.seed(2)
truth <- rbinom(500, 1, 0.4)
prob  <- pmin(pmax(truth * 0.6 + runif(500) * 0.5, 0), 1)
attr(cl_roc(prob, truth), "auc")
#> [1] 1
```
