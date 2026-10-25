# Double-logistic seasonal trajectory

The standard four-phase form used across land-surface phenology.

## Usage

``` r
cl_pheno_curve(doy, base = 0.15, amplitude = 0.6, sos = 120, eos = 280,
  slope_up = 0.12, slope_down = 0.10)
```

## Arguments

- doy:

  Day of year.

- base:

  Winter baseline value.

- amplitude:

  Seasonal amplitude.

- sos:

  Start and end of season, in days.

- eos:

  Start and end of season, in days.

- slope_up:

  Transition rates.

- slope_down:

  Transition rates.

## Value

Numeric vector of index values.

## Examples

``` r
plot_ready <- cl_pheno_curve(1:365)
round(range(plot_ready), 3)
#> [1] 0.15 0.75
```
