# Cloud and shadow detection

## Methods are registered, not hard-coded

``` r

cl_methods()
#>         method     type                              requires
#> 1        fmask physical blue, green, red, nir, swir16, swir22
#> 2           qa physical                                      
#> 3 randomforest  learned                        blue, red, nir
#> 4  s2cloudless  learned                        blue, red, nir
#> 5    threshold physical                      blue, green, red
#> 6         unet  learned                        blue, red, nir
#> 7      xgboost  learned                        blue, red, nir
#>                                    reference
#> 1      Zhu & Woodcock style decision cascade
#> 2  Native producer QA (CFMask / Sen2Cor SCL)
#> 3 not implemented: needs pre-trained weights
#> 4 not implemented: needs pre-trained weights
#> 5              Brightness-whiteness baseline
#> 6 not implemented: needs pre-trained weights
#> 7 not implemented: needs pre-trained weights
```

Each method declares the bands it needs, so applicability can be checked
before anything is downloaded:

``` r

cl_methods(sensor = "sentinel-2-msi")$method
#> [1] "fmask"        "qa"           "randomforest" "s2cloudless"  "threshold"   
#> [6] "unet"         "xgboost"
cl_methods(sensor = "generic-multispectral")$method
#> [1] "qa"           "randomforest" "s2cloudless"  "threshold"    "unet"        
#> [6] "xgboost"
```

A four-band UAV camera has no SWIR, so Fmask-style detection is
unavailable and the package says so rather than silently producing
nonsense.

## Adding your own method

``` r

cl_method_register(
  "blue_ratio",
  requires = c("blue", "red"),
  type = "statistical",
  reference = "example",
  fun = function(bands, geom, drv, cut = 1.3, ...) {
    r <- bands$blue / pmax(bands$red, 1e-6)
    1 / (1 + exp(-(r - cut) / 0.1))
  })

"blue_ratio" %in% cl_methods()$method
#> [1] TRUE
```

Nothing else changes.
[`cl_probability()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_probability.md),
[`cl_compare()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_compare.md)
and the evaluation tools work with it immediately, because they address
methods through the registry rather than by name.

## Reading the producer’s own mask

``` r

qa <- matrix(0L, 4, 4)
qa[1, ] <- bitwShiftL(1L, 3)   # cloud bit
qa[2, ] <- bitwShiftL(1L, 4)   # cloud-shadow bit
dec <- cl_qa_decode(qa, "landsat-8-9-oli")
dec$class
#>      [,1] [,2] [,3] [,4]
#> [1,]    4    4    4    4
#> [2,]    5    5    5    5
#> [3,]    1    1    1    1
#> [4,]    1    1    1    1
```

The same call works for Sentinel-2, whose SCL is categorical rather than
bit-packed, because the decoding rule lives in the sensor driver. Both
are translated into the one vocabulary given by
[`cl_classes()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_classes.md),
which is what makes CFMask, Sen2Cor and a neural mask directly
comparable.

## Shadow geometry

``` r

cl_shadow_offset(height = 2000, sun_zenith = 45, sun_azimuth = 180)
#>                 dx   dy
#> [1,] -2.449294e-13 2000
cl_shadow_offset(height = 2000, sun_zenith = 45, sun_azimuth = 90)
#>         dx            dy
#> [1,] -2000 -1.224647e-13
```

Sun in the south puts the shadow to the north; sun in the east puts it
to the west. Displacement is `height * tan(zenith)`, with an optional
correction for the satellite not viewing from nadir — negligible for
Landsat, worth applying across a Sentinel-2 swath.

When a thermal band exists, cloud height can be estimated directly:

``` r

bt <- matrix(300, 40, 40)
cloud <- matrix(FALSE, 40, 40); cloud[15:25, 15:25] <- TRUE
bt[cloud] <- 282
cl_cloud_height(bt, cloud)
#> $height
#> [1] 2769.231
#> 
#> $range
#> [1] 2769.231 2769.231
```

Without a thermal band the honest answer is a search range, not a
number, and that is what is returned.

## Terrain shadow is not cloud shadow

``` r

dem <- matrix(0, 40, 40); dem[, 30:40] <- 600
sum(cl_terrain_shadow(dem, sun_zenith = 75, sun_azimuth = 90, res = 30))
#> [1] 1160
sum(cl_terrain_shadow(dem, sun_zenith = 75, sun_azimuth = 270, res = 30))
#> [1] 0
```

In rugged terrain both are dark and both correlate with aspect. Neither
Fmask, Sen2Cor’s SCL, nor single-date neural masks separate them
explicitly, so topographic shadow is routinely absorbed into
cloud-shadow statistics. Computing it from a DEM lets
[`cl_shadow()`](https://ehsanrahimi666.github.io/cloudscape/reference/cl_shadow.md)
exclude it.

## Where masks should not be trusted

``` r

bands <- list(blue = matrix(0.2, 20, 20), green = matrix(0.35, 20, 20),
              red = matrix(0.3, 20, 20), nir = matrix(0.4, 20, 20),
              swir16 = matrix(0.05, 20, 20))
r <- cl_reliability(bands)
names(r$flags)
#> [1] "snow_ice"    "bright_bare" "water_edge"  "sun_glint"
round(mean(r$reliability), 3)
#> [1] 0.55
```

High NDSI with low SWIR is snow, which every published cloud mask
confuses with cloud to some degree. Flagging it means a derived
statistic can carry an honest caveat instead of an unqualified number.
