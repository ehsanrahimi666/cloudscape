# Clear observation counts per cell and period

Clear observation counts per cell and period

## Usage

``` r
cl_clear_obs(obs, by = c("year", "month", "season", "all"), threshold = 0.2,
  model = c("independent", "clustered", "empirical"), grid = NULL, coverage
  = TRUE)
```

## Arguments

- obs:

  A `cl_obs` table.

- by:

  Period granularity: `"year"`, `"month"`, `"season"` or `"all"`.
  Seasons are meteorological (DJF, MAM, JJA, SON), with December counted
  in the following year's DJF.

- threshold:

  Usability threshold. An observation is usable when at least
  `1 - threshold` of the cell was observed and cloud-free (with
  `coverage = TRUE`) or when its cloud fraction is at most `threshold`.

- model:

  Clear-probability model, see
  [`cl_clear_prob`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_prob.md).

- grid:

  Optional `cl_grid` recorded on the output.

- coverage:

  Take the valid share of the cell into account; see
  [`cl_clear_prob`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_prob.md).
  Tables without a `valid_fraction` column are treated as fully
  observed.

## Value

A `cl_stats` table with metrics `n_scenes` (acquisitions), `n_clear_obs`
(usable acquisitions), `cloud_fraction` and `p_clear`, the mean of
[`cl_clear_prob`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_prob.md).
With models `"independent"` and `"empirical"`, `p_clear` times
`n_scenes` is the expected number of clear observations of a pixel at a
random location in the cell; with `"clustered"` it is the expected
number of usable acquisitions. Acquisitions without a cloud fraction
count in `n_scenes` but not in the sample size of the other metrics.

## Examples

``` r
set.seed(1)
o <- cl_obs(cell = rep(1:2, each = 40),
            date = rep(seq(as.Date("2023-01-01"), by = "9 days", length.out = 40), 2),
            cloud_fraction = c(runif(40, 0, .4), runif(40, .5, 1)),
            sensor = "sentinel-2-msi")
summary(cl_clear_obs(o, by = "year"))
#>           metric        unit n_rows        min     median       mean        max
#> 1 cloud_fraction    fraction      2  0.2058099  0.4871256  0.4871256  0.7684413
#> 2    n_clear_obs       count      2  0.0000000 10.5000000 10.5000000 21.0000000
#> 3       n_scenes       count      2 40.0000000 40.0000000 40.0000000 40.0000000
#> 4        p_clear probability      2  0.2315587  0.5128744  0.5128744  0.7941901
```
