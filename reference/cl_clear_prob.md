# Probability that a pixel in a cell is clear

Converting a scene-level cloud fraction into a per-pixel clear
probability requires an assumption, and the choice of assumption matters
more than most users expect.

`"independent"` sets `P(clear) = 1 - cloud_fraction`. This treats cloud
as spatially random within the footprint. Cloud is strongly clustered,
so this systematically **overestimates** the number of usable
observations for a specific location: a scene reported as 50 percent
cloudy is far more often half covered by one cloud deck than uniformly
half-obscured. It is the assumption implicit in any analysis that uses
scene cloud percentage as a usability measure, and it is why tier A
results should be read as an upper bound.

`"clustered"` applies a Beta-distributed correction with concentration
`kappa`, reproducing the observed U-shaped distribution of pixel-level
cloud occurrence within partly cloudy scenes.

`"empirical"` requires tier `"qa"` or `"mask"` data, where the fraction
was measured for the cell rather than inferred from the scene, and
applies no correction.

## Usage

``` r
cl_clear_prob(obs, model = c("independent", "clustered", "empirical"), kappa
  = 0.5)
```

## Arguments

- obs:

  A `cl_obs` table.

- model:

  One of `"independent"`, `"clustered"`, `"empirical"`.

- kappa:

  Beta concentration for `"clustered"`; lower means more clustered.
  Values near 0.5 match reported pixel-scale behaviour.

## Value

Numeric vector of clear probabilities, one per row of `obs`.
