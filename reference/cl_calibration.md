# Probability calibration

A detector can discriminate well and still be badly calibrated, in which
case its probabilities cannot be used to weight observations or
propagate uncertainty. This reports the reliability curve together with
the Brier score and expected calibration error.

## Usage

``` r
cl_calibration(prob, truth, bins = 10L)
```

## Arguments

- prob:

  Predicted probabilities.

- truth:

  Binary reference.

- bins:

  Number of probability bins.

## Value

A data frame with one row per bin, with `brier` and `ece` attributes.
