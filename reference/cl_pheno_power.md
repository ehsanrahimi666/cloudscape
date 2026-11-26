# Phenological retrieval error under cloud loss

Simulates the effect of missing observations on the retrieval of
phenological dates. In each replicate, a reference curve is sampled at
the acquisition dates that are retained, noise is added, the curve is
refitted, and the errors of the start of season, peak and end of season
are recorded.

## Usage

``` r
cl_pheno_power(dates, cloud_fraction = 0.4, threshold = 0.2, curve = NULL,
  noise = 0.03, n_sim = 100L, model = c("dbl_logistic", "spline"), tau = 1,
  valid_fraction = 1, retention = c("pixel", "cell"), tolerance = 5,
  persistence = NULL, seed = NULL)
```

## Arguments

- dates:

  Acquisition dates available in the year, in any order.

- cloud_fraction:

  Cloud fraction for each acquisition, or a single value.

- threshold:

  Usability threshold for `retention = "cell"`.

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

- tau:

  Decorrelation time of cloud loss in days; 0 gives independent losses.

- valid_fraction:

  Valid share of the cell for each acquisition, or a single value.

- retention:

  `"pixel"` or `"cell"`; see the section on retention.

- tolerance:

  Error tolerance in days for the `p_within_*` outputs.

- persistence:

  Deprecated. A lag-one autocorrelation between consecutive
  acquisitions; converted to `tau` with the median interval.

- seed:

  Random seed.

## Value

A list with `summary` (a one-row data frame: numbers of acquisitions and
retained observations, median absolute errors and median biases of start
of season, peak, end of season and season length, the interquartile
range of start of season, the failure and insufficient-data rates, and
the `p_within_*` probabilities), `replicates`, and `reference`, the fit
to the complete reference curve.

## Which observations are retained

With `retention = "pixel"` (the default) each replicate is the series of
a pixel at a random location in the cell. Acquisition \\i\\ is observed
and clear with probability \\q_i = v_i (1 - c_i)\\, where \\c_i\\ is the
cloud fraction and \\v_i\\ the valid share of the cell (1 for scene
metadata, in which cloud is assumed to be spread evenly over the
footprint). The expected number of retained observations is therefore
\\\sum_i q_i\\, the expected number of clear observations of a pixel
reported by
[`cl_clear_obs`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_obs.md).
Clear and cloudy states are drawn from a latent Gaussian process whose
correlation between two acquisitions \\\Delta t\\ days apart is
\\\exp(-\Delta t / \tau)\\: acquisition \\i\\ is clear when the latent
value is below \\\Phi^{-1}(q_i)\\, which keeps every marginal
probability exact while losses cluster in time according to the elapsed
time between acquisitions. `tau = 0` gives independent losses.

With `retention = "cell"`, an acquisition is retained when at least
`1 - threshold` of the cell was observed and cloud-free, as in
[`cl_clear_obs`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_obs.md);
the retained set is then the same in every replicate and only the noise
varies.

## Success and failure

A replicate succeeds when at least six observations are retained, the
fit converges, and the fitted curve has a start of season, a peak and an
end of season in that order. Errors are summarised over successful
replicates. Because errors conditional on success can look small when
most replicates fail, `p_within_*` report the probability, over all
replicates, that the replicate succeeded and the error of that date was
at most `tolerance` days; `p_within_all` requires all three dates to be
within it.

## Examples

``` r
d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "10 days")
r <- cl_pheno_power(d, cloud_fraction = 0.5, n_sim = 30, seed = 1)
r$summary[, c("n_retained_median", "sos_mae", "failure_rate", "p_within_all")]
#>   n_retained_median sos_mae failure_rate p_within_all
#> 1              18.5     1.6          0.2          0.2
```
