# Accuracy metrics for a binary or multi-class mask

Accuracy metrics for a binary or multi-class mask

## Usage

``` r
cl_validate(pred, truth, positive = 1, levels = NULL)
```

## Arguments

- pred:

  Predicted mask.

- truth:

  Reference mask.

- positive:

  For binary input, the value treated as the positive class.

- levels:

  Optional class levels for multi-class input.

## Value

A data frame of per-class precision, recall, F1 and IoU plus overall and
balanced accuracy, with an attribute `confusion`.

## Examples

``` r
set.seed(1)
truth <- matrix(rbinom(400, 1, 0.3), 20, 20)
pred  <- truth; pred[sample(400, 40)] <- 1 - pred[sample(400, 40)]
cl_validate(pred, truth)
#> <cl_validation> 400 pixels
#>   overall accuracy : 0.95 
#>   balanced accuracy: 0.9598 
#>   MCC              : 0.8857 
#>  class n_truth n_pred precision recall specificity     f1    iou
#>      0     287    271    0.9926 0.9373      0.9823 0.9642 0.9308
#>      1     113    129    0.8605 0.9823      0.9373 0.9174 0.8473
```
