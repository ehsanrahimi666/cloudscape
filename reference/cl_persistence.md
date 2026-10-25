# Estimate the temporal persistence of cloud from an observation record

Cloud occurrence is autocorrelated in time, and that autocorrelation
degrades time-series retrievals largely independently of how much cloud
there is: it concentrates observation loss into contiguous runs that can
remove an entire seasonal transition while leaving the annual
observation count almost unchanged. Quantifying it therefore requires
its own estimator.

For the two-state chain used throughout cloudscape, with marginal cloud
probability \\p\\ and lag-1 autocorrelation \\\rho\\, \$\$p\_{11} = p +
(1-p)\rho, \qquad p\_{01} = p(1-\rho),\$\$ so that \\\rho = p\_{11} -
p\_{01}\\. The estimator is therefore the difference between the
empirical probability that a cloudy acquisition is followed by another
cloudy one and the probability that a clear acquisition is followed by a
cloudy one. This requires no model fitting and is unbiased for a
stationary chain.

Acquisitions are irregularly spaced, so transitions are counted only
between consecutive acquisitions of the same sensor and only when the
interval falls within `max_interval` days. The median interval actually
used is returned so that \\\rho\\ can be interpreted per unit time
rather than per acquisition.

## Usage

``` r
cl_persistence(obs, threshold = 0.2, max_interval = 20, min_pairs = 10, by =
  c("all", "year", "season"))
```

## Arguments

- obs:

  A `cl_obs` table.

- threshold:

  Cloud fraction above which an acquisition counts as cloudy.

- max_interval:

  Longest gap in days across which a transition is still counted. Pairs
  separated by more than this are dropped, because a transition across a
  three-month gap carries no information about persistence at the
  acquisition scale.

- min_pairs:

  Minimum usable transitions required to report an estimate.

- by:

  Period granularity, or `"all"` to pool the whole record.

## Value

A data frame with one row per cell, sensor and period, giving `p_cloud`,
`p11`, `p01`, `rho`, `median_interval_days`, `n_pairs`,
`mean_cloudy_run` (the mean length of consecutive cloudy acquisitions)
and `decorrelation_days`.

## Attenuation

The estimate is a **lower bound** on the persistence that matters for a
specific location. Whether an acquisition is usable at a given cell is
inferred by thresholding a scene-level cloud fraction, which is a noisy
proxy for the underlying state. Independent misclassification attenuates
an estimated autocorrelation towards zero by approximately \\(1 -
\alpha - \beta)^2\\, where \\\alpha\\ and \\\beta\\ are the two
misclassification rates. In simulation with a realistic overlap between
the cloudy and clear cloud-fraction distributions, a true \\\rho\\ of
0.6 is recovered as approximately 0.41 and a true 0.3 as approximately
0.20. Estimates from tier `"qa"` or `"mask"` data, where usability is
measured for the cell rather than inferred from the scene, are
correspondingly less attenuated. Reported values should therefore be
read as conservative.

## Comparing rho across places

`rho` is a lag-1 autocorrelation, and the lag is whatever the local
acquisition interval happens to be. That interval is not constant:
orbits converge towards the poles, so a high-latitude cell may be
observed daily while a tropical cell is observed every five days.
Because autocorrelation decays with lag, raw `rho` values from different
latitudes are not comparable, and the bias runs against the tropics.

`decorrelation_days` removes this. Assuming exponential decay,
\\\rho(\Delta t) = \exp(-\Delta t / \tau)\\, so \\\tau = -\Delta t /
\log \rho\\: the time over which cloud state becomes uninformative about
itself, in days, independent of how often the cell happens to be
observed. It is `NA` where `rho` is not positive.

Note also that `mean_cloudy_run` is not a measure of clustering. A cell
that is cloudy 94 percent of the time has long cloudy runs whatever its
autocorrelation, because the marginal alone produces them. `rho`
measures persistence beyond what the marginal explains; run length
confounds the two.

## Examples

``` r
d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
ts <- cl_simulate_series(d, p_cloud = 0.5, persistence = 0.6, seed = 1)
o <- cl_obs(1, ts$date, ts$cloud_fraction, sensor = "sentinel-2-msi")
cl_persistence(o)$rho
#> [1] 0.2904762
```
