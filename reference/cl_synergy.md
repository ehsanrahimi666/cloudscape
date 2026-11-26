# Multi-constellation revisit synergy

Answers the question a study designer actually asks: if I combine these
sensors, how many observations do I get, and how does that change
through time?

Effective revisit is not a constant. Landsat 9 joined Landsat 8 in late
2021, roughly halving the Landsat interval from that point; Sentinel-2B
joined 2A in 2017 and 2C in 2024. A study spanning 2014 to the present
therefore has a non-stationary sampling density, and comparing early and
late years without accounting for it confounds acquisition capacity with
whatever is being measured.

## Usage

``` r
cl_synergy(sensors, start, end, by = c("year", "month"), latitude = 0)
```

## Arguments

- sensors:

  Character vector of sensor ids or aliases.

- start:

  Analysis period.

- end:

  Analysis period.

- by:

  Reporting granularity, `"year"` or `"month"`.

- latitude:

  Optional latitude used to inflate the number of acquisitions for
  orbital side-lap, approximated as `1 / cos(latitude)`.

## Value

A data frame with columns `period`, `sensor`, `days` (days of the period
inside `start` to `end`), `n_platforms` (platform-years or
platform-months in operation divided by the period length),
`nominal_obs` (acquisitions of one platform at the nominal revisit),
`combined_obs` and `effective_revisit_days` (`days / combined_obs`).
Periods cut by `start` or `end` are reported for the days they contain.

## Examples

``` r
cl_synergy(c("landsat-8-9-oli", "sentinel-2-msi"),
           start = "2015-01-01", end = "2025-12-31", by = "year")[1:6, ]
#>    period          sensor days n_platforms nominal_obs combined_obs
#> 23   2015        COMBINED  365   1.5260274     59.3125      42.0125
#> 1    2015 landsat-8-9-oli  365   1.0000000     22.8125      22.8125
#> 2    2015  sentinel-2-msi  365   0.5260274     36.5000      19.2000
#> 24   2016        COMBINED  366   2.0000000     59.4750      59.4750
#> 3    2016 landsat-8-9-oli  366   1.0000000     22.8750      22.8750
#> 4    2016  sentinel-2-msi  366   1.0000000     36.6000      36.6000
#>    effective_revisit_days
#> 23               8.687891
#> 1               16.000000
#> 2               19.010417
#> 24               6.153846
#> 3               16.000000
#> 4               10.000000
```
