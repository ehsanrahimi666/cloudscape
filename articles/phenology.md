# Designing a phenology study around cloud

## The question

You want land-surface phenology from optical imagery. Before committing,
you want to know whether the site will yield a defensible green-up date,
and if not, what would change that.

Mean cloud cover cannot answer this. Two sites with identical 60% annual
cloud can differ by a factor of three in retrieval error, depending on
*when* the cloud falls and how it clusters.

## Step 1: how many observations, and when

``` r

dates <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
site <- cl_simulate_series(dates, p_cloud = 0.62, persistence = 0.4, seed = 11)
obs <- cl_obs(cell = 1, date = site$date, cloud_fraction = site$cloud_fraction,
              sensor = "sentinel-2-msi")

cl_stats_wide(cl_gaps(obs, threshold = 0.2, critical = 21))
#>   cell period         sensor max_gap_days mean_gap_days n_clear_obs
#> 1    1   2023 sentinel-2-msi           95            26          13
```

The maximum gap matters more than the count. A 40-day gap that happens
to straddle green-up removes the transition entirely, and no amount of
data later in the season recovers it.

## Step 2: translate into days of error

``` r

p <- cl_pheno_power(dates, cloud_fraction = site$cloud_fraction,
                    n_sim = 300, seed = 2)
p$summary[, c("n_usable_median", "sos_mae", "sos_iqr", "sos_bias",
              "failure_rate")]
#>   n_usable_median sos_mae sos_iqr sos_bias failure_rate
#> 1              34     2.3     4.7      0.2   0.04333333
```

Read the failure rate first. It is the fraction of years in which the
double-logistic fit does not converge at all. A study that fails to
produce an estimate is a different problem from one that produces a
biased estimate, and the two get confused when only mean error is
reported.

## Step 3: how sensitive is this to clustering?

``` r

grid <- expand.grid(cloud = c(0.4, 0.6, 0.8), rho = c(0, 0.35, 0.7))
res <- do.call(rbind, Map(function(cl, rho) {
  s <- cl_pheno_power(dates, cloud_fraction = cl, persistence = rho,
                      n_sim = 250, seed = 5)$summary
  data.frame(cloud = cl, rho = rho, usable = s$n_usable_median,
             sos_mae = s$sos_mae, failure = round(s$failure_rate, 3))
}, grid$cloud, grid$rho))
res
#>   cloud  rho usable sos_mae failure
#> 1   0.4 0.00   43.0    0.80   0.000
#> 2   0.6 0.00   29.0    1.10   0.020
#> 3   0.8 0.00   14.0    2.20   0.220
#> 4   0.4 0.35   43.0    1.00   0.008
#> 5   0.6 0.35   28.5    1.30   0.036
#> 6   0.8 0.35   14.0    3.35   0.296
#> 7   0.4 0.70   43.5    0.90   0.044
#> 8   0.6 0.70   28.0    1.65   0.136
#> 9   0.8 0.70   13.0    7.20   0.412
```

Along any row of constant cloud, the number of usable observations
barely moves, but the failure rate climbs with `rho`. Clustering does
not remove observations; it removes them from where they matter. Any
feasibility assessment that assumes independent cloud loss will be
optimistic, and the more so the more clustered the local climate.

## Step 4: would adding a sensor fix it?

``` r

sy <- cl_synergy(c("landsat-8-9-oli", "sentinel-2-msi"),
                 "2015-01-01", "2025-12-31")
sy[sy$period == "2025", c("sensor", "n_platforms", "combined_obs",
                          "effective_revisit_days")]
#>             sensor n_platforms combined_obs effective_revisit_days
#> 33        COMBINED           5      155.125               2.354553
#> 21 landsat-8-9-oli           2       45.625               8.005479
#> 22  sentinel-2-msi           3      109.500               3.335616
```

Adding Landsat to Sentinel-2 shortens effective revisit substantially.
Whether that converts into usable observations depends on whether the
two constellations are clouded at the same times, which they largely are
— so the gain is real but smaller than the revisit numbers alone
suggest. Verify with the actual archive rather than assuming.

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
#> [1] 0.189
#> 
#> $n_sim
#> [1] 2000
```

## What to report in a paper

State the acquisition count, the maximum gap, and the simulated
retrieval error with its failure rate, for each site or stratum.
Reporting mean cloud cover alone leaves reviewers unable to judge
whether the phenological conclusions are supportable, and leaves you
unable to explain why one site behaved differently from another.

A caveat worth carrying: everything above uses tier-A cloud fractions,
which are scene averages. They give an upper bound on usable
observations. Recomputing with `tier = "qa"` on the actual quality
layers will lower these numbers, and the gap between the two is itself
informative.
