# Confusion matrix

Confusion matrix

## Usage

``` r
cl_confusion(pred, truth, levels = NULL, labels = NULL)
```

## Arguments

- pred:

  Predicted class codes or logical mask.

- truth:

  Reference class codes or logical mask.

- levels:

  Optional class levels; defaults to the union observed.

- labels:

  Optional class labels.

## Value

A table with predictions in rows and reference in columns.
