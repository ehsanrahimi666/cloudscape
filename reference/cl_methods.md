# List available cloud-probability methods

List available cloud-probability methods

## Usage

``` r
cl_methods(sensor = NULL)
```

## Arguments

- sensor:

  Optional sensor id; when supplied, only methods whose required bands
  the sensor provides are returned.

## Value

A data frame of methods.

## Examples

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
cl_methods(sensor = "sentinel-2-msi")   # no thermal-based methods
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
