# ROC curve and area under it

ROC curve and area under it

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

  Number of thresholds to evaluate.

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
