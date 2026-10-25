# Phenological retrieval error under realistic cloud loss

Simulates the effect of missing observations on phenological metric
retrieval. For each replicate, a reference curve is sampled at the
supplied acquisition dates, observations are dropped according to their
cloud fraction, noise is added, the curve is refitted, and the retrieval
error is recorded.

The output is directly interpretable: an expected absolute error in days
for start of season, end of season and length of season, together with
the failure rate, meaning the fraction of replicates that produced no
start of season: too few usable observations (reported separately as
`insufficient_rate`), a fit that did not converge, or a fitted curve
with no start-of-season crossing. In heavily clouded regions the failure
rate is often the more important number, because a study there does not
produce a biased estimate, it produces no estimate.

## Usage

``` r
cl_pheno_power(dates, cloud_fraction = 0.4, threshold = 0.2, curve = NULL,
  noise = 0.03, n_sim = 100L, model = c("dbl_logistic", "spline"),
  persistence = 0.35, seed = NULL)
```

## Arguments

- dates:

  Acquisition dates available in the year.

- cloud_fraction:

  Cloud fraction for each acquisition, or a single value.

- threshold:

  Maximum cloud fraction for a usable observation.

- curve:

  Function of day-of-year giving the reference trajectory, or a list of
  arguments passed to
  [`cl_pheno_curve`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_curve.md).

- noise:

  Observation noise standard deviation.

- n_sim:

  Number of replicates.

- model:

  Fitting model passed to
  [`cl_pheno_fit`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_pheno_fit.md).

- persistence:

  Lag-1 autocorrelation of cloud loss, in \\0, 1), using the same chain
  as
  [`cl_simulate_series`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_simulate_series.md).
  0 gives independent loss, which is unrealistic and optimistic:
  independent loss thins the series uniformly and almost never removes a
  whole transition, whereas clustered loss regularly removes green-up
  entirely.

- seed:

  Random seed.

## Value

A list with `summary` (a one-row data frame of median absolute errors,
interquartile ranges, failure rate and insufficient-data rate),
`replicates`, and `reference`, the fit to the complete reference curve.

## Examples

``` r
d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "10 days")
r <- cl_pheno_power(d, cloud_fraction = 0.5, n_sim = 30, seed = 1)
r$summary[, c("n_usable_median", "sos_mae", "failure_rate")]
#>   n_usable_median sos_mae failure_rate
#> 1            17.5     1.7   0.03333333
```
