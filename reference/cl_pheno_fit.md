# Fit a seasonal trajectory and extract phenological metrics

Fits a double-logistic curve or a smoothing spline to the observations,
and extracts the start and end of season as the days on which the fitted
curve crosses `threshold` of its amplitude before and after the peak.

For the double logistic, the position of the season is located before
the nonlinear fit. With the transition dates and rates held fixed, the
model is linear in `base` and `amplitude`, so every candidate pair of
start and end dates on a five-day grid has a closed-form least-squares
fit. The pair with the smallest residual sum of squares starts the
optimiser. If that fit does not converge, the best pair at a start date
at least 30 days away is tried, and then `sos = 110`, `eos = 290`. The
first converged fit is returned.

## Usage

``` r
cl_pheno_fit(doy, value, model = c("dbl_logistic", "spline"), threshold =
  0.5, start = NULL)
```

## Arguments

- doy:

  Day of year of each observation.

- value:

  Observed index values.

- model:

  `"dbl_logistic"` or `"spline"`.

- threshold:

  Amplitude fraction defining SOS and EOS for the threshold extraction,
  following common practice.

- start:

  Optional named list of starting values for the double logistic, with
  elements `base`, `amplitude`, `sos`, `eos`, `slope_up` and
  `slope_down` in any order. Values outside the parameter bounds are
  moved to the nearest bound. When `NULL` (the default), starting values
  are derived from the data, as described above.

## Value

A list with `sos`, `eos`, `los`, `peak_doy`, `peak_value`, `converged`
and `fit`.
