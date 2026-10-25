# Rescale stored integers to reflectance

Rescale stored integers to reflectance

## Usage

``` r
cl_scale(x, sensor = NULL, clamp = c(0, 1.6))
```

## Arguments

- x:

  A `cl_scene` or named list of matrices.

- sensor:

  Sensor id, when `x` is a list.

- clamp:

  Clip to a physically plausible range.

## Value

The rescaled object.
