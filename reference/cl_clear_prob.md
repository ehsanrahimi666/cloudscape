# Probability that a pixel in a cell is clear

Converts the cloud fraction of each observation into a clear
probability.

`"independent"` sets the probability that a pixel at a random location
in the cell is clear to `1 - cloud_fraction`. With tier `"metadata"` the
fraction is that of the whole scene, so the value assumes that the cell
is as cloudy as the scene; scene metadata carry no information on where
in the footprint the cloud was.

`"empirical"` requires tier `"qa"` or `"mask"` data, where the fraction
was measured for the cell rather than inferred from the scene, and also
returns `1 - cloud_fraction`.

`"clustered"` answers a different question: the probability that the
cell observation is usable at `threshold`, that is, that at least
`1 - threshold` of the cell is observed and clear, when the clear share
of the cell follows a Beta distribution with mean `1 - cloud_fraction`
and concentration `kappa`. Small `kappa` makes cells mostly clear or
mostly cloudy. The model is intended for scene-level fractions, where
the share of a particular cell is unknown.

## Usage

``` r
cl_clear_prob(obs, model = c("independent", "clustered", "empirical"), kappa
  = 0.5, coverage = TRUE, threshold = 0.2)
```

## Arguments

- obs:

  A `cl_obs` table.

- model:

  One of `"independent"`, `"clustered"`, `"empirical"`.

- kappa:

  Beta concentration for `"clustered"`.

- coverage:

  Take the valid share of the cell (column `valid_fraction`, present in
  tier `"qa"`) into account, so that the probability refers to a pixel
  at a random location in the cell rather than to a pixel within the
  observed part. Has no effect on tables without that column.

- threshold:

  Usability threshold for `"clustered"`, see
  [`cl_clear_obs`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_clear_obs.md).

## Value

Numeric vector of probabilities, one per row of `obs`.
