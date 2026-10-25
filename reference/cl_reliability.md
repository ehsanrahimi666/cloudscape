# Flag conditions where cloud masks are known to be unreliable

Returns a per-pixel reliability score. Low values mark surfaces on which
every published cloud mask has documented weaknesses, so that a
downstream statistic can be reported with an honest caveat rather than
an unqualified number.

## Usage

``` r
cl_reliability(bands, dem = NULL, sun_zenith = NULL, sun_azimuth = NULL, res
  = 30)
```

## Arguments

- bands:

  Named list of reflectance matrices.

- dem:

  Optional elevation matrix, used to flag terrain shadow risk.

- sun_zenith:

  Illumination geometry, for terrain shadow.

- sun_azimuth:

  Illumination geometry, for terrain shadow.

- res:

  Pixel size in metres.

## Value

A list with `reliability` in \\0, 1\\ and named logical `flags`.
