# Getting started with cloudscape

## The question this package is for

Most cloud software answers “which pixels are cloudy”. That is a means,
not an end. The question behind it is usually “can I do my study here”,
and answering that needs three things the mask alone does not give you:
an equal-area spatial unit, an honest account of what scene metadata can
and cannot tell you, and a translation from cloud statistics into the
units your conclusions are stated in.

## An equal-area spatial unit

Scene footprints are the wrong unit for statistics. A WRS-2 scene covers
less ground area at high latitude, and neighbouring paths overlap more,
so counting images per path/row conflates acquisition density with
geometry. It also makes Landsat and Sentinel-2 incomparable, since their
footprints differ.

``` r

g <- cl_grid(res = 100000)
box <- function(lat) cbind(c(0, 2, 2, 0, 0), c(lat, lat, lat + 2, lat + 2, lat))
nrow(cl_grid_index(box(50), g))   # cells covered at 50N
#> [1] 4
nrow(cl_grid_index(box(70), g))   # same 2x2 degrees at 70N
#> [1] 2
```

Every cell has the same true ground area, so counts are directly
comparable across latitude and across sensors.

## Units are enforced, not assumed

``` r

cl_stats(1:2, "cloud_fraction", c(0.3, 1.4))
#> Error:
#> ! Metric 'cloud_fraction' has value 1.4 outside its permitted range [0, 1] (row 2).
```

``` r

s <- cl_stats(1:3, "n_scenes", c(20, 21, 22), period = "2023",
              denominator = "cell-year")
s$denominator
#> [1] "cell-year" "cell-year" "cell-year"
```

The denominator is part of the data. A total across ten years divided by
ten is a mean *per year*; if it is labelled as a mean per scene, the
numbers become physically impossible for the stated unit, and nothing in
a plain data frame would catch that.

## From cloud fraction to usable observations

Scene-level cloud cover is a scene average. Turning it into a statement
about one cell requires an assumption. The `"independent"` model gives
the expected cloud-free share of the cell,
`valid_fraction * (1 - cloud_fraction)`, as if the cell were as cloudy
as the scene; scene metadata record no valid share, so it is taken as 1.
The `"clustered"` model gives the probability that the cell observation
is usable at the threshold when cloud is clustered, so that cells of a
partly cloudy scene tend to be either mostly clear or mostly cloudy:

``` r

d <- seq(as.Date("2023-01-01"), as.Date("2023-12-31"), by = "5 days")
ts <- cl_simulate_series(d, p_cloud = 0.55, persistence = 0.35, seed = 2)
obs <- cl_obs(cell = 1, date = ts$date, cloud_fraction = ts$cloud_fraction,
              sensor = "sentinel-2-msi")
head(cbind(cloud = obs$cloud_fraction,
           independent = cl_clear_prob(obs, "independent"),
           clustered = cl_clear_prob(obs, "clustered", threshold = 0.2)), 4)
#>          cloud independent  clustered
#> [1,] 0.8991638   0.1008362 0.05364023
#> [2,] 0.4875932   0.5124068 0.38542204
#> [3,] 0.3328357   0.6671643 0.55742611
#> [4,] 0.6605037   0.3394963 0.22344113
```

Quality layers measure the cloud over the cell itself (tier `"qa"`),
which removes the need for either assumption.

## What actually breaks a time series

Not the mean. The longest stretch without a usable image.

``` r

cl_stats_wide(cl_gaps(obs, threshold = 0.2, critical = 30))
#>   cell period         sensor max_gap_days mean_gap_days n_clear_dates
#> 1    1   2023 sentinel-2-msi           50         14.64            24
```

## Translating into days

``` r

res <- lapply(c(0.3, 0.7, 0.9), function(p)
  cl_pheno_power(d, cloud_fraction = p, n_sim = 200, seed = 4)$summary)
do.call(rbind, res)[, c("n_retained_median", "sos_mae", "failure_rate")]
#>   n_retained_median sos_mae failure_rate
#> 1                51     0.6         0.00
#> 2                23     1.2         0.05
#> 3                 8     8.0         0.56
```

The failure rate is often the more important column. In heavily clouded
regions a study does not return a biased green-up date, it returns none
at all.

## Constellations change through time

``` r

sy <- cl_synergy(c("landsat-8-9-oli", "sentinel-2-msi"),
                 "2014-01-01", "2025-12-31")
sy[sy$sensor == "COMBINED" & sy$period %in% c("2014", "2018", "2022", "2025"),
   c("period", "n_platforms", "effective_revisit_days")]
#>    period n_platforms effective_revisit_days
#> 25   2014           1              16.000000
#> 29   2018           3               3.809524
#> 33   2022           4               3.076923
#> 36   2025           5               2.352941
```

Sampling density is not stationary. Landsat 9 joined in late 2021 and
Sentinel-2C in 2024, so a trend computed across such a period partly
reflects acquisition capacity rather than the environment. Any long
time-series analysis should account for this explicitly.

## Where to go next

- [`vignette("detection")`](https://ehsanrahimi666.github.io/cloudscape/articles/detection.md)
  — cloud and shadow detection, and comparing methods
- [`vignette("benchmarking")`](https://ehsanrahimi666.github.io/cloudscape/articles/benchmarking.md)
  — simulation-based evaluation
- [`vignette("phenology")`](https://ehsanrahimi666.github.io/cloudscape/articles/phenology.md)
  — designing a phenology study around cloud
