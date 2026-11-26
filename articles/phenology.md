# Designing a phenology study around cloud

## The question

You want land-surface phenology from optical imagery. Before committing,
you want to know whether the site will yield a defensible green-up date,
and if not, what would change that.

Mean cloud cover cannot answer this. Two sites with the same annual
cloud cover can differ in retrieval error, depending on *when* the cloud
falls and how it clusters in time.

## Step 1: how many observations, and when

``` r

dates <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
site <- cl_simulate_series(dates, p_cloud = 0.62, persistence = 0.4, seed = 11)
obs <- cl_obs(cell = 1, date = site$date, cloud_fraction = site$cloud_fraction,
              sensor = "sentinel-2-msi")

cl_stats_wide(cl_gaps(obs, threshold = 0.2, critical = 21))
#>   cell period         sensor max_gap_days mean_gap_days n_clear_dates
#> 1    1   2023 sentinel-2-msi           95      26.14286            13
```

The maximum gap matters more than the count. A 40-day gap that happens
to straddle green-up removes the transition entirely, and no amount of
data later in the season recovers it.

## Step 2: translate into days of error

``` r

p <- cl_pheno_power(dates, cloud_fraction = site$cloud_fraction,
                    n_sim = 300, seed = 2)
p$summary[, c("n_retained_median", "sos_mae", "sos_iqr", "sos_bias",
              "failure_rate", "p_within_all")]
#>   n_retained_median sos_mae sos_iqr sos_bias failure_rate p_within_all
#> 1                30     1.9     3.8      0.1         0.06         0.34
```

Read the failure rate first. It is the share of replicates in which too
few observations remained, the fit did not converge, or the fitted curve
lacked a start, peak or end of season. A study that fails to produce an
estimate is a different problem from one that produces a biased
estimate, and the two get confused when only the error of successful
retrievals is reported. `p_within_all` combines both: the probability
that a retrieval succeeds and all three dates fall within `tolerance`
days (5 by default) of the truth.

## Step 3: how sensitive is this to clustering?

``` r

grid <- expand.grid(cloud = c(0.4, 0.6, 0.8), tau = c(0, 5, 20))
res <- do.call(rbind, Map(function(cl, tau) {
  s <- cl_pheno_power(dates, cloud_fraction = cl, tau = tau,
                      n_sim = 250, seed = 5)$summary
  data.frame(cloud = cl, tau = tau, retained = s$n_retained_median,
             sos_mae = s$sos_mae, failure = round(s$failure_rate, 3),
             within = round(s$p_within_all, 3))
}, grid$cloud, grid$tau))
res
#>   cloud tau retained sos_mae failure within
#> 1   0.4   0     44.0    0.80   0.004  0.592
#> 2   0.6   0     30.0    1.10   0.016  0.476
#> 3   0.8   0     15.0    1.90   0.204  0.208
#> 4   0.4   5     45.0    0.80   0.012  0.576
#> 5   0.6   5     30.0    1.15   0.056  0.372
#> 6   0.8   5     14.5    2.60   0.268  0.112
#> 7   0.4  20     44.0    0.90   0.048  0.500
#> 8   0.6  20     29.0    1.80   0.148  0.236
#> 9   0.8  20     14.0    3.40   0.460  0.076
```

`tau` is the decorrelation time of cloud loss in days. At constant
cloud, the number of retained observations barely changes with `tau`,
because every acquisition keeps its clear probability; what changes is
how the losses are arranged in time. Long decorrelation times remove
runs of consecutive acquisitions, which can take out a whole transition.
Estimate `tau` for the site with
[`cl_persistence()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_persistence.md)
rather than assuming it.

## Step 4: would adding a sensor fix it?

``` r

sy <- cl_synergy(c("landsat-8-9-oli", "sentinel-2-msi"),
                 "2015-01-01", "2025-12-31")
sy[sy$period == "2025", c("sensor", "n_platforms", "combined_obs",
                          "effective_revisit_days")]
#>             sensor n_platforms combined_obs effective_revisit_days
#> 33        COMBINED           5      155.125               2.352941
#> 21 landsat-8-9-oli           2       45.625               8.000000
#> 22  sentinel-2-msi           3      109.500               3.333333
```

Adding Landsat to Sentinel-2 shortens the effective revisit. Whether
that converts into usable observations depends on whether the two
constellations are clouded at the same times, so the gain in usable
observations can be smaller than the revisit numbers suggest. Verify
with the actual archive rather than assuming.

## Step 5: state the design explicitly

``` r

cl_feasibility(p_clear = 0.38, n_acquisitions = 73, n_required = 15,
               window_days = 365, max_gap = 30)
#> $expected_obs
#> [1] 27.74
#> 
#> $p_sufficient
#> [1] 0.9995714
#> 
#> $p_gap_ok
#> [1] 0.182
#> 
#> $n_sim
#> [1] 2000
```

## What to report in a paper

State the acquisition count, the maximum gap, and the simulated
retrieval error with its failure rate, for each site or stratum.
Reporting mean cloud cover alone leaves readers unable to judge whether
the phenological conclusions are supportable, and leaves you unable to
explain why one site behaved differently from another.

A caveat worth carrying: everything above uses simulated cloud
fractions. With real data, scene-level cloud cover is a footprint
average that says nothing about where in the scene the cloud was;
quality layers read with
[`cl_qa_obs()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_qa_obs.md)
measure each cell, and the difference between the two tiers is itself
informative.
