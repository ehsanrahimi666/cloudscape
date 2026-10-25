# Clear observation counts per cell and period

Clear observation counts per cell and period

## Usage

``` r
cl_clear_obs(obs, by = c("year", "month", "season", "all"), threshold = 0.2,
  model = c("independent", "clustered", "empirical"), grid = NULL)
```

## Arguments

- obs:

  A `cl_obs` table.

- by:

  Period granularity: `"year"`, `"month"`, `"season"` or `"all"`.

- threshold:

  Maximum cloud fraction for an observation to count as usable.

- model:

  Clear-probability model, see
  [`cl_clear_prob`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_prob.md).

- grid:

  Optional `cl_grid` recorded on the output.

## Value

A `cl_stats` table with metrics `n_scenes`, `n_clear_obs`,
`cloud_fraction` and `p_clear`.

## Examples

``` r
set.seed(1)
o <- cl_obs(cell = rep(1:2, each = 40),
            date = rep(seq(as.Date("2023-01-01"), by = "9 days", length.out = 40), 2),
            cloud_fraction = c(runif(40, 0, .4), runif(40, .5, 1)),
            sensor = "sentinel-2-msi")
summary(cl_clear_obs(o, by = "year"))
#> Note: tier 'metadata' with model 'independent' gives an optimistic upper bound on clear observations. See ?cl_clear_prob.
#>           metric        unit n_rows        min     median       mean        max
#> 1 cloud_fraction    fraction      2  0.2058099  0.4871256  0.4871256  0.7684413
#> 2    n_clear_obs       count      2  0.0000000 10.5000000 10.5000000 21.0000000
#> 3       n_scenes       count      2 40.0000000 40.0000000 40.0000000 40.0000000
#> 4        p_clear probability      2  0.2315587  0.5128744  0.5128744  0.7941901
```
